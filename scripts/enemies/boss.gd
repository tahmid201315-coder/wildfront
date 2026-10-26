extends "res://scripts/enemies/enemy.gd"
## One script, three bosses. Each has its own attack set and phase changes.
##   grove_guardian   : slam, thorn fan, erupting roots, summons stalkers, charge in phase 2
##   furnace_colossus : fire fan, shockwave slam, burning ground, overheating charge (vulnerable after it)
##   core_architect   : flying; rotating beam, orb ring, gravity pull, blink, shield phases with sentinel adds

var bid: String = ""
var bdef: Dictionary = {}
var arena_c: Vector3 = Vector3.ZERO
var arena_r: float = 26.0
var phase: int = 1
var zones: Array = []        # hazard zones {pos, r, delay, life, dmg, tick, t, done, mesh, kind}
var adds: Array = []
var shield: bool = false
var vulnerable: bool = false
var center_h: float = 3.5
var _atk: String = ""
var _atk_t: float = 0.0
var _next_cd: float = 1.5
var _charge_dir: Vector3 = Vector3.ZERO
var _beam_a: float = 0.0
var _beam_mesh: MeshInstance3D = null
var _tele: MeshInstance3D = null
var _summoned: Dictionary = {}
var _fly: bool = false
var _fly_y: float = 0.0
var _dmg_tick: float = 0.0


func setup_boss(id: String, arena_pos: Vector3, radius: float) -> void:
	bid = id
	bdef = Data.bosses[id]
	arena_c = arena_pos
	arena_r = radius
	var d := {"hp": bdef["hp"], "ai": "boss", "xp": bdef["xp"], "drops": bdef["drops"], "detect": radius, "leash": radius * 2.0,
		"speed": 5.0, "range": 5.0, "dmg": 20.0, "windup": 1.0, "cooldown": 2.0, "armor": 0.0}
	match id:
		"grove_guardian":
			d["speed"] = 4.6; d["dmg"] = 26.0; center_h = 3.6; d["armor"] = 0.1
		"furnace_colossus":
			d["speed"] = 4.2; d["dmg"] = 32.0; center_h = 3.8; d["armor"] = 0.15
		"core_architect":
			d["speed"] = 4.5; d["dmg"] = 24.0; center_h = 4.0; _fly = true
	setup(id, d, arena_pos)
	hit_radius = 2.0
	super_armor = true
	metallic = id != "grove_guardian"
	state = "dormant"
	if _fly:
		_fly_y = 3.5


func hit_center() -> Vector3:
	return global_position + Vector3(0, center_h, 0)


# ------------------------------------------------------------------ damage
func take_damage(dmg: float, from_pos: Vector3, knock: float, src: Node, crit: bool) -> void:
	if not alive or state in ["dormant", "intro", "dead"]:
		return
	if shield:
		Sfx.play_at("hit_metal", global_position, 0.6, 40.0)
		if Game.world:
			Game.world.show_damage(hit_center() + Vector3(0, 1.0, 0), 0.0, false)
		return
	var d := dmg * (1.0 - armor) * (1.5 if vulnerable else 1.0)
	hp -= d
	_flash = 0.12
	if Game.world:
		Game.world.spawn_burst(hit_center(), Color(1.0, 0.85, 0.4) if crit else Color(0.9, 0.3, 0.2), 5, 3.0)
		Game.world.show_damage(hit_center() + Vector3(0, 1.0, 0), d, crit or vulnerable)
	if hp <= 0.0:
		die(src)
		return
	_check_phase()


func _frac() -> float:
	return hp / max_hp


func _check_phase() -> void:
	var f := _frac()
	var np := 1
	if bid == "core_architect":
		np = 1 if f > 0.66 else (2 if f > 0.33 else 3)
	else:
		np = 1 if f > 0.6 else (2 if f > 0.3 else 3)
	if bid == "core_architect" and np > phase and not _summoned.has(np):
		hp = minf(hp, max_hp * (0.66 if np == 2 else 0.33))
		_begin_summon_shield(np)
	if np > phase:
		phase = np
		if Game.world:
			_banner(String(bdef["name"]).to_upper(), "Phase %d" % phase)
			Game.world.player.shake(0.5)
		Sfx.play_at("roar", global_position, 0.7, 80.0)


func _begin_summon_shield(np: int) -> void:
	_summoned[np] = true
	shield = true
	_atk = ""
	_enter("summon")
	if Game.world:
		_banner("THE ARCHITECT RAISES A SHIELD", "Destroy the sentinels")


# ------------------------------------------------------------------ main AI
func _ai(delta: float, pl: Node3D) -> void:
	_desired = Vector3.ZERO
	_tick_zones(delta, pl)
	var pd := Vector2(pl.global_position.x - arena_c.x, pl.global_position.z - arena_c.z).length()
	_sync_hud()
	if state == "dormant":
		if pd < arena_r * 0.9 and not pl.dead and not Game.bosses_defeated.has(bid):
			_enter("intro")
			if Game.world:
				_banner(String(bdef["name"]).to_upper(), String(bdef["title"]))
				pl.shake(0.4)
			Sfx.play_at("roar", global_position, 0.6, 90.0)
		return
	if pl.dead or pd > arena_r + 30.0:
		_reset_fight()
		return
	if state == "intro":
		_face(_flat_to(pl.global_position), delta, 3.0)
		if st_t > 2.4:
			_enter("choose")
			_next_cd = 0.8
		return
	_face_target(delta, pl)
	match state:
		"choose":
			_choose(delta, pl)
		"windup", "attack", "channel":
			_run_attack(delta, pl)
		"recover":
			vulnerable = bid == "furnace_colossus" and _atk == "charge"
			_set_flash(0.25 if vulnerable else 0.0, Color(1.0, 0.5, 0.1))
			if st_t > (3.0 if vulnerable else 1.0):
				vulnerable = false
				_enter("choose")
				_next_cd = 0.6
		"summon":
			_summon_state(delta, pl)


func _face_target(delta: float, pl: Node3D) -> void:
	if state not in ["attack", "recover"] or _atk == "beam":
		_face(_flat_to(pl.global_position), delta, 2.5 if state != "windup" else 1.5)


func _choose(delta: float, pl: Node3D) -> void:
	var to := _flat_to(pl.global_position)
	var dist := to.length()
	var spd := float(def["speed"]) * (1.0 + 0.15 * (phase - 1))
	if not _fly or dist > 14.0:
		if dist > 5.0 + (6.0 if _fly else 0.0):
			_desired = to.normalized() * spd
	elif dist < 8.0:
		_desired = -to.normalized() * spd * 0.7
	_next_cd -= delta
	if _next_cd > 0.0:
		return
	_atk = _pick(dist)
	_atk_t = 0.0
	_enter("windup")
	_hit_done = false
	if _atk == "beam":
		_beam_a = atan2(-to.x, -to.z) - 1.0
	if _atk == "charge":
		_charge_dir = to.normalized()


func _pick(dist: float) -> String:
	var r := randf()
	match bid:
		"grove_guardian":
			if dist < 7.0 and r < 0.55:
				return "slam"
			if phase >= 2 and r < 0.3 and dist > 8.0:
				return "charge"
			if phase >= 2 and not _summoned.has(phase) and r < 0.35:
				return "summon"
			return "roots" if r < 0.55 else ("thorns" if r < 0.85 else "slam")
		"furnace_colossus":
			if dist < 8.0 and r < 0.5:
				return "slam"
			if r < 0.25 and dist > 8.0:
				return "charge"
			return "flames" if r < 0.6 else "fan"
		_:
			if r < 0.25:
				return "beam"
			if r < 0.5:
				return "orbs"
			if r < 0.7 and phase >= 2:
				return "gravity"
			if r < 0.85:
				return "blink"
			return "orbs"


func _wind_time() -> float:
	var t := 1.0
	match _atk:
		"slam": t = 1.2
		"charge": t = 1.1
		"roots": t = 0.6
		"thorns": t = 0.9
		"summon": t = 1.4
		"fan": t = 0.9
		"flames": t = 0.8
		"beam": t = 1.2
		"orbs": t = 0.9
		"gravity": t = 1.0
		"blink": t = 0.4
	return t * (1.0 - 0.1 * (phase - 1))


func _run_attack(delta: float, pl: Node3D) -> void:
	var to := _flat_to(pl.global_position)
	if state == "windup":
		var f := clampf(st_t / _wind_time(), 0.0, 1.0)
		_set_flash(0.15 + 0.5 * f, Color(1.0, 0.35, 0.15))
		if _atk in ["slam", "gravity"]:
			_show_tele(_slam_r() if _atk == "slam" else 5.0, f, global_position if _atk == "slam" else pl.global_position)
		if _atk == "charge":
			_face(to, delta, 6.0)
			_charge_dir = to.normalized()
		if st_t >= _wind_time():
			_clear_tele()
			_enter("attack")
			_do_attack_start(pl)
		return
	_set_flash(0.0)
	_atk_t += delta
	_do_attack_tick(delta, pl)


func _slam_r() -> float:
	return 7.0 + (1.5 if phase >= 2 else 0.0) + (1.5 if bid == "furnace_colossus" else 0.0)


func _do_attack_start(pl: Node3D) -> void:
	var w := Game.world
	match _atk:
		"slam":
			Sfx.play_at("slam", global_position, 1.0, 80.0)
			w.spawn_burst(global_position + Vector3(0, 0.3, 0), Color(0.6, 0.55, 0.5), 30, 7.0)
			pl.shake(0.7)
			var d := Vector2(pl.global_position.x - global_position.x, pl.global_position.z - global_position.z).length()
			if d < _slam_r() and pl.global_position.y - global_position.y < 2.2:
				pl.hurt(float(def["dmg"]) * 1.2, global_position, 14.0)
			if bid == "furnace_colossus":
				_ring_zone(global_position, _slam_r())
		"thorns", "fan":
			var base := _facing_dir()
			var n := (5 if phase == 1 else 7) + (2 if phase == 3 else 0)
			var o := global_position + Vector3(0, center_h, 0)
			for i in n:
				var a := (float(i) / float(n - 1) - 0.5) * 1.4
				var dir := base.rotated(Vector3.UP, a)
				w.spawn_projectile(o, dir, float(def["dmg"]) * 0.55, false, 15.0,
					Color(0.5, 0.9, 0.3) if bid == "grove_guardian" else Color(1.0, 0.5, 0.15), self)
			Sfx.play_at("shot", global_position, 0.6, 70.0)
		"roots":
			var n2 := 3 + phase
			for i in n2:
				var p := pl.global_position
				if i > 0:
					var a2 := randf() * TAU
					p += Vector3(cos(a2), 0, sin(a2)) * randf_range(2.0, 7.0)
				_add_zone(p, 2.4, 1.1 + i * 0.25, 0.0, float(def["dmg"]) * 0.9, 0.0, Color(0.5, 0.8, 0.25))
		"flames":
			for i in 3 + phase:
				var a3 := randf() * TAU
				var p2 := pl.global_position + Vector3(cos(a3), 0, sin(a3)) * randf_range(0.0, 8.0)
				_add_zone(p2, 3.2, 0.8, 9.0, 7.0, 0.5, Color(1.0, 0.4, 0.1))
		"charge":
			Sfx.play_at("roar", global_position, 1.2, 80.0)
			_kb = Vector3.ZERO
		"summon":
			_summon_adds("stalker", 2)
			_summoned[phase] = true
		"orbs":
			var n3 := 10 + phase * 2
			var o2 := global_position + Vector3(0, center_h, 0)
			for i in n3:
				var a4 := TAU * float(i) / float(n3) + randf() * 0.2
				w.spawn_projectile(o2, Vector3(cos(a4), -0.05, sin(a4)), float(def["dmg"]) * 0.5, false, 12.0, Color(0.5, 0.9, 1.0), self)
			Sfx.play_at("shot", global_position, 0.5, 80.0)
		"gravity":
			Sfx.play_at("wail", global_position, 0.6, 80.0)
		"blink":
			var a5 := randf() * TAU
			var np := arena_c + Vector3(cos(a5), 0, sin(a5)) * randf_range(8.0, arena_r * 0.7)
			global_position = Vector3(np.x, WG.height_at(np.x, np.z), np.z)
			Sfx.play_at("blink", global_position, 1.0, 70.0)
			w.spawn_burst(global_position + Vector3(0, 3, 0), Color(0.5, 0.9, 1.0), 20, 5.0)
		"beam":
			Sfx.play_at("machine_on", global_position, 1.0, 80.0)


func _facing_dir() -> Vector3:
	return Vector3(-sin(_facing), 0, -cos(_facing))


func _do_attack_tick(delta: float, pl: Node3D) -> void:
	match _atk:
		"slam", "thorns", "fan", "roots", "flames", "summon", "orbs", "blink":
			if _atk_t > 0.5:
				_atk_done(0.9)
		"charge":
			var spd := 17.0 + 3.0 * phase
			_desired = _charge_dir * spd
			_facing = lerp_angle(_facing, atan2(-_charge_dir.x, -_charge_dir.z), 0.3)
			var d := _flat_to(pl.global_position).length()
			if not _hit_done and d < 3.8:
				_hit_done = true
				pl.hurt(float(def["dmg"]) * 1.3, global_position, 16.0)
			var out := Vector2(global_position.x - arena_c.x, global_position.z - arena_c.z).length() > arena_r - 2.0
			if _atk_t > 1.1 or out:
				_atk_done(1.0)
				if bid == "furnace_colossus":
					Sfx.play_at("slam", global_position, 0.8, 80.0)
		"gravity":
			var pc := global_position
			var tp: Vector3 = pl.global_position
			var dd := Vector3(tp.x - pc.x, 0, tp.z - pc.z)
			if _atk_t < 1.6:
				pl.velocity += (-dd.normalized() * 9.0 * delta) if dd.length() > 1.5 else Vector3.ZERO
			if _atk_t >= 1.6 and not _dmg_tick_done():
				w_explode(pl)
			if _atk_t > 2.0:
				_atk_done(1.0)
		"beam":
			_beam_a += delta * (1.1 + 0.3 * phase)
			var dir := Vector3(-sin(_beam_a), 0, -cos(_beam_a))
			_update_beam(dir)
			var rel := _flat_to(pl.global_position)
			var along := rel.dot(dir)
			var perp := (rel - dir * along).length()
			_dmg_tick -= delta
			if along > 0.0 and along < 40.0 and perp < 1.2 and pl.global_position.y - global_position.y < 3.5 and _dmg_tick <= 0.0:
				_dmg_tick = 0.4
				pl.hurt(float(def["dmg"]) * 0.7, global_position, 6.0)
			if _atk_t > 2.8:
				_clear_beam()
				_atk_done(1.2)


func _dmg_tick_done() -> bool:
	return _hit_done


func w_explode(pl: Node3D) -> void:
	_hit_done = true
	Sfx.play_at("slam", global_position, 1.0, 80.0)
	if Game.world:
		Game.world.spawn_burst(global_position + Vector3(0, 1, 0), Color(0.5, 0.9, 1.0), 30, 8.0)
	pl.shake(0.6)
	if _flat_to(pl.global_position).length() < 6.0:
		pl.hurt(float(def["dmg"]) * 1.4, global_position, 14.0)


func _atk_done(rec: float) -> void:
	_enter("recover")
	_hit_done = false
	_next_cd = 0.0
	if _atk == "charge" and bid != "furnace_colossus":
		_set_flash(0.0)
	# shorten recover when enraged
	st_t = -0.2 * float(phase - 1) if _atk != "charge" or bid != "furnace_colossus" else 0.0
	_desired = Vector3.ZERO


# ------------------------------------------------------------------ summons / shield
func _summon_adds(kind: String, n: int) -> void:
	var w := Game.world
	for i in n:
		var a := TAU * float(i) / float(n) + randf()
		var p := global_position + Vector3(cos(a), 0, sin(a)) * 7.0
		var e := preload("res://scripts/enemies/enemy.gd").new()
		w.add_child(e)
		e.setup(kind, Data.enemies[kind], Vector3(p.x, WG.height_at(p.x, p.z), p.z))
		e.global_position = Vector3(p.x, WG.height_at(p.x, p.z) + 0.3, p.z)
		e.target = w.player
		if kind == "sentinel":
			e._booted = true
			e._enter("chase")
		else:
			e._enter("chase")
		e.def = e.def.duplicate()
		e.def["leash"] = 200.0
		w.enemies.append(e)
		adds.append(e)
		Sfx.play_at("blink", e.global_position, 1.0, 60.0)


func _summon_state(delta: float, pl: Node3D) -> void:
	if st_t < 0.2 and adds.is_empty():
		_summon_adds("sentinel", 2)
		_desired = Vector3.ZERO
	_set_flash(0.3 + 0.2 * sin(st_t * 8.0), Color(0.4, 0.8, 1.0))
	adds = adds.filter(func(a): return is_instance_valid(a) and a.alive)
	if adds.is_empty() and st_t > 1.0:
		shield = false
		_set_flash(0.0)
		if Game.world:
			_banner("SHIELD DOWN", "Strike now")
		vulnerable = true
		_enter("recover")
		_atk = ""
		st_t = -1.5
		var t := get_tree().create_timer(2.5)
		t.timeout.connect(func(): vulnerable = false)


# ------------------------------------------------------------------ zones
func _add_zone(pos: Vector3, r: float, delay: float, life: float, dmg: float, tick: float, col: Color) -> void:
	var p := Vector3(pos.x, WG.height_at(pos.x, pos.z), pos.z)
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.06
	cm.radial_segments = 20
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(col.r, col.g, col.b, 0.25)
	cm.material = mat
	m.mesh = cm
	m.top_level = true
	Game.world.add_child(m)
	m.global_position = p + Vector3(0, 0.1, 0)
	zones.append({"pos": p, "r": r, "delay": delay, "life": life, "dmg": dmg, "tick": tick, "t": 0.0, "acc": 0.0, "done": false, "mesh": m, "col": col})


func _ring_zone(c: Vector3, r: float) -> void:
	for i in 8:
		var a := TAU * float(i) / 8.0
		var p := c + Vector3(cos(a), 0, sin(a)) * (r + 1.5)
		_add_zone(p, 2.2, 0.6 + 0.05 * i, 4.0, 5.0, 0.5, Color(1.0, 0.4, 0.1))


func _tick_zones(delta: float, pl: Node3D) -> void:
	for z in zones.duplicate():
		z["t"] += delta
		var mat: StandardMaterial3D = z["mesh"].mesh.material
		var inside: bool = Vector2(pl.global_position.x - z["pos"].x, pl.global_position.z - z["pos"].z).length() < z["r"]
		if z["t"] < z["delay"]:
			mat.albedo_color.a = 0.15 + 0.35 * (z["t"] / z["delay"])
			continue
		if not z["done"]:
			z["done"] = true
			mat.albedo_color.a = 0.6
			if z["life"] <= 0.0:
				if inside and pl.global_position.y - z["pos"].y < 2.5:
					pl.hurt(z["dmg"], z["pos"], 10.0)
				if Game.world:
					Game.world.spawn_burst(z["pos"] + Vector3(0, 0.5, 0), z["col"], 14, 5.0)
				Sfx.play_at("slam", z["pos"], 0.7, 50.0)
		if z["life"] > 0.0:
			z["acc"] += delta
			if z["acc"] >= z["tick"]:
				z["acc"] = 0.0
				if inside and pl.global_position.y - z["pos"].y < 2.0:
					pl.hurt(z["dmg"], Vector3.ZERO, 0.0)
			if z["t"] - z["delay"] > z["life"]:
				z["mesh"].queue_free()
				zones.erase(z)
		elif z["t"] - z["delay"] > 0.25:
			z["mesh"].queue_free()
			zones.erase(z)


func _clear_zones() -> void:
	for z in zones:
		if is_instance_valid(z["mesh"]):
			z["mesh"].queue_free()
	zones.clear()


# ------------------------------------------------------------------ indicators
func _show_tele(r: float, f: float, at: Vector3) -> void:
	if _tele == null:
		_tele = MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 1.0
		cm.bottom_radius = 1.0
		cm.height = 0.05
		cm.radial_segments = 28
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(1.0, 0.2, 0.1, 0.3)
		cm.material = m
		_tele.mesh = cm
		_tele.top_level = true
		add_child(_tele)
	_tele.global_position = Vector3(at.x, WG.height_at(at.x, at.z) + 0.1, at.z)
	_tele.scale = Vector3(r, 1, r) * (0.3 + 0.7 * f)


func _clear_tele() -> void:
	if _tele:
		_tele.queue_free()
		_tele = null


func _update_beam(dir: Vector3) -> void:
	if _beam_mesh == null:
		_beam_mesh = MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.7, 0.7, 40.0)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.6, 1.0, 1.0)
		bm.material = m
		_beam_mesh.mesh = bm
		_beam_mesh.top_level = true
		add_child(_beam_mesh)
	var o := global_position + Vector3(0, center_h * 0.5 + 0.4, 0)
	_beam_mesh.global_position = o + dir * 20.0
	_beam_mesh.look_at(o + dir * 40.0, Vector3.UP)


func _clear_beam() -> void:
	if _beam_mesh:
		_beam_mesh.queue_free()
		_beam_mesh = null


# ------------------------------------------------------------------ hud / reset / death
func _banner(a: String, b: String) -> void:
	if Game.world and Game.world.hud:
		Game.world.hud.banner(a, b)


func _sync_hud() -> void:
	var h: Node = Game.world.hud if Game.world else null
	if h == null:
		return
	var on := state not in ["dormant", "dead"] and alive
	h.show_boss = on
	if on:
		h.boss_name = String(bdef["name"])
		h.boss_frac = _frac()


func _reset_fight() -> void:
	hp = max_hp
	phase = 1
	shield = false
	vulnerable = false
	_summoned.clear()
	_clear_zones()
	_clear_beam()
	_clear_tele()
	for a in adds:
		if is_instance_valid(a):
			a.alive = false
			a.queue_free()
			Game.world.enemies.erase(a)
	adds.clear()
	global_position = Vector3(arena_c.x, WG.height_at(arena_c.x, arena_c.z), arena_c.z)
	_enter("dormant")
	_set_flash(0.0)
	if Game.world and Game.world.hud:
		Game.world.hud.show_boss = false


func die(src: Node) -> void:
	if not alive:
		return
	_clear_zones()
	_clear_beam()
	_clear_tele()
	for a in adds:
		if is_instance_valid(a) and a.alive:
			a.die(null)
	super.die(src)
	vulnerable = false
	shield = false
	Game.defeat_boss(bid)
	if Game.world:
		if Game.world.hud:
			Game.world.hud.show_boss = false
		_banner("%s DEFEATED" % String(bdef["name"]).to_upper(), "")
		Game.world.player.shake(0.8)
		var so = preload("res://scripts/world/site_objects.gd")
		var c = so.LootContainer.new()
		Game.world.add_child(c)
		var p := global_position + Vector3(4, 0, 0)
		c.global_position = Vector3(p.x, WG.height_at(p.x, p.z), p.z)
		c.setup("chest_" + bid, "boss_chest", "", "treasure")


func _drop_loot() -> void:
	for d in bdef["drops"]:
		var n := randi_range(int(d[1]), int(d[2]))
		if n > 0:
			Game.give_item(String(d[0]), n)
			Game.toast("+%d %s" % [n, Data.item_name(String(d[0]))], "item")


# ------------------------------------------------------------------ movement / animation
func _move(delta: float) -> void:
	var v := _desired
	if state in ["windup", "intro", "summon", "dormant"] and _atk != "charge":
		v = Vector3.ZERO
	var hv := Vector3(velocity.x, 0, velocity.z).move_toward(v, 40.0 * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	if _fly:
		var gh := maxf(WG.height_at(global_position.x, global_position.z), 0.0)
		velocity.y = (gh + _fly_y + sin(Time.get_ticks_msec() * 0.002) * 0.4 - global_position.y) * 3.0
	elif not is_on_floor():
		velocity.y -= 24.0 * delta
	else:
		velocity.y = -1.0
	move_and_slide()
	rotation.y = _facing
	var off := Vector2(global_position.x - arena_c.x, global_position.z - arena_c.z)
	if off.length() > arena_r:
		var n := off.normalized() * arena_r
		global_position.x = arena_c.x + n.x
		global_position.z = arena_c.z + n.y


func _animate(delta: float) -> void:
	var spd := Vector3(velocity.x, 0, velocity.z).length()
	_walk_phase += delta * (2.0 + spd * 0.5)
	var sw := sin(_walk_phase) * clampf(spd / 4.0, 0.0, 1.0) * 0.6
	var up := 0.0
	if state == "windup":
		up = clampf(st_t / maxf(_wind_time(), 0.1), 0.0, 1.0)
	elif state == "attack":
		up = 1.0 - clampf(_atk_t / 0.25, 0.0, 1.0)
	if _atk in ["orbs", "beam", "gravity", "blink", "summon"] and _fly:
		up *= 0.5
	_rot("leg0", sw, 0, 0)
	_rot("leg1", -sw, 0, 0)
	_rot("arm0", -up * 2.6 + sw * 0.4, 0, 0.1)
	_rot("arm1", -up * 2.6 - sw * 0.4, 0, -0.1)
	if state == "dormant":
		_rot("arm0", 0.1, 0, 0.1)
		_rot("arm1", 0.1, 0, -0.1)
	if _fly:
		_rot("ring", 0, delta * 1.4, 0, true)
		_rot("ring2", 0, -delta * 2.2, 0, true)
		if pivots.has("core"):
			pivots["core"].scale = Vector3.ONE * (1.0 + 0.2 * sin(Time.get_ticks_msec() * 0.006))


func _dead_anim(delta: float) -> void:
	st_t += delta
	var f := clampf(st_t / 2.5, 0.0, 1.0)
	model.position.y = -f * (1.0 if not _fly else 0.0)
	model.rotation.x = f * 0.4 * (1.0 if not _fly else 0.0)
	model.scale = Vector3.ONE * size * (1.0 - (f if _fly else 0.0))
	if f >= 1.0:
		queue_free()
