extends CharacterBody3D
## Hostile creature with a small state machine. AI flavour is chosen from the data table's "ai" field:
## melee_fast (Forest Stalker), melee_heavy (Rockback Brute), ranged (Crystal Wraith), sentinel (Ruin Sentinel).
## Bosses extend this class.

const WG = preload("res://scripts/world/world_gen.gd")
const EnemyModels = preload("res://scripts/gfx/enemy_models.gd")

signal died(enemy)

var eid: String = ""
var def: Dictionary = {}
var alive: bool = true
var hp: float = 50.0
var max_hp: float = 50.0
var home: Vector3 = Vector3.ZERO
var den: Dictionary = {}
var state: String = "idle"
var st_t: float = 0.0
var hit_radius: float = 0.8
var metallic: bool = false
var size: float = 1.0
var model: Node3D
var pivots: Dictionary = {}
var materials: Array = []
var target: Node3D = null
var _walk_phase: float = 0.0
var _flash: float = 0.0
var _atk_cd: float = 1.0
var _wander_t: float = 0.0
var _wander_dir: Vector3 = Vector3.ZERO
var _facing: float = 0.0
var _hit_done: bool = false
var _kb: Vector3 = Vector3.ZERO
var _indicator: MeshInstance3D = null
var _strafe_dir: float = 1.0
var _volley: int = 0
var _booted: bool = true
var _guard: bool = false
var _atk_count: int = 0
var _float_y: float = 0.0
var _stagger_res: float = 0.0
var armor: float = 0.0
var super_armor: bool = false
var visible_range: float = 140.0


func setup(id: String, def_data: Dictionary, home_pos: Vector3) -> void:
	eid = id
	def = def_data
	home = home_pos
	max_hp = float(def["hp"])
	hp = max_hp
	armor = float(def.get("armor", 0.0))
	size = float(def.get("size", 1.0))
	hit_radius = 0.7 * size
	metallic = String(def["ai"]) == "sentinel"
	collision_layer = 8
	collision_mask = 1 | 2
	floor_snap_length = 0.6
	floor_max_angle = deg_to_rad(55.0)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45 * size
	cap.height = maxf(1.6 * size, cap.radius * 2.2)
	cs.shape = cap
	cs.position.y = cap.height * 0.5
	add_child(cs)
	_build_model(id)
	global_position = home_pos
	_facing = randf() * TAU
	if String(def["ai"]) == "sentinel":
		_booted = false
		super_armor = true
	if String(def["ai"]) == "melee_heavy":
		super_armor = true
	_setup_extra()


func _setup_extra() -> void:
	pass


func _build_model(id: String) -> void:
	model = EnemyModels.build(id)
	add_child(model)
	for c in model.get_children():
		pivots[c.name] = c
		for m in c.get_children():
			if m is MeshInstance3D:
				materials.append(m.material_override if m.material_override else m.get_surface_override_material(0))
	# the material is stored on the mesh surface; make per-instance copies for flashing
	materials.clear()
	for c in model.get_children():
		for m in c.get_children():
			if m is MeshInstance3D:
				var mat: ShaderMaterial = (m.mesh.surface_get_material(0) as ShaderMaterial)
				if mat:
					var dup := mat.duplicate() as ShaderMaterial
					m.material_override = dup
					materials.append(dup)
	model.scale = Vector3.ONE * size
	if String(def["ai"]) == "ranged":
		_float_y = 0.2


func hit_center() -> Vector3:
	return global_position + Vector3(0, 1.0 * size, 0)


func _set_flash(a: float, col: Color = Color(1, 0.25, 0.15)) -> void:
	for m in materials:
		m.set_shader_parameter("flash_amt", a)
		m.set_shader_parameter("flash_col", Color(col.r, col.g, col.b))


# ----------------------------------------------------------------- damage
func take_damage(dmg: float, from_pos: Vector3, knock: float, src: Node, crit: bool) -> void:
	if not alive:
		return
	var d := dmg * (1.0 - armor)
	if _guard and src != null:
		var to_src: Vector3 = (from_pos - global_position)
		to_src.y = 0
		var fwd := Vector3(-sin(_facing), 0, -cos(_facing))
		if to_src.length() > 0.1 and fwd.dot(to_src.normalized()) > 0.3:
			d *= 0.35
			Sfx.play_at("hit_metal", global_position, 0.7, 40.0)
			knock *= 0.3
	hp -= d
	_flash = 0.18
	if Game.world:
		Game.world.spawn_burst(hit_center(), Color(1.0, 0.85, 0.4) if crit else Color(0.9, 0.3, 0.2), 6 if not crit else 10, 3.0)
		Game.world.show_damage(hit_center() + Vector3(0, 0.5, 0), d, crit)
	if src != null and target == null:
		target = src as Node3D
		if state in ["idle", "retreat"]:
			state = "chase"
	if hp <= 0.0:
		die(src)
		return
	if from_pos != Vector3.ZERO and knock > 0.0:
		var away := global_position - from_pos
		away.y = 0
		_kb = away.normalized() * knock * (0.4 if super_armor else 1.0)
	var stagger := not super_armor or dmg >= 24.0
	if stagger and state not in ["stagger", "dead"] and _stagger_res <= 0.0:
		_stagger_res = 1.2
		_enter("stagger")


func die(src: Node) -> void:
	if not alive:
		return
	alive = false
	state = "dead"
	st_t = 0.0
	collision_layer = 0
	if _indicator:
		_indicator.queue_free()
		_indicator = null
	if Game.world:
		Game.world.enemies.erase(self)
	Sfx.play_at("enemy_die", global_position, 1.0, 50.0)
	_drop_loot()
	Game.add_stat("kill:" + eid)
	Game.add_stat("kills_total")
	Game.add_xp(int(def.get("xp", 10)))
	if Game.has_skill("en4") and randf() < 0.25:
		Game.give_item("machine_part", 1)
		Game.toast("+1 Machine Component", "item")
	died.emit(self)


func _drop_loot() -> void:
	for d in def.get("drops", []):
		var n := randi_range(int(d[1]), int(d[2]))
		if n > 0:
			Game.give_item(String(d[0]), n)
			Game.toast("+%d %s" % [n, Data.item_name(String(d[0]))], "item")


# ----------------------------------------------------------------- state helpers
func _enter(s: String) -> void:
	state = s
	st_t = 0.0
	_hit_done = false
	if s != "windup" and _indicator:
		_indicator.queue_free()
		_indicator = null


func _player() -> Node3D:
	var w: Node = Game.world
	return w.player if w else null


func _flat_to(p: Vector3) -> Vector3:
	var d := p - global_position
	d.y = 0
	return d


func _face(dir: Vector3, delta: float, rate: float = 8.0) -> void:
	if dir.length() < 0.01:
		return
	_facing = lerp_angle(_facing, atan2(-dir.x, -dir.z), clampf(delta * rate, 0.0, 1.0))


func _can_see_player(pl: Node3D, mult: float = 1.0) -> bool:
	if pl.dead:
		return false
	var d := _flat_to(pl.global_position).length()
	var r := float(def["detect"]) * mult
	if pl.crouch_on:
		r *= 0.55
	if Game.world and Game.world.sky and Game.world.sky.night_amount > 0.5 and eid == "stalker":
		r *= 1.4
	return d < r


# ----------------------------------------------------------------- main loop
func _physics_process(delta: float) -> void:
	if not Game.is_playing() and Game.state != Game.State.DIALOGUE:
		return
	if state == "dead":
		_dead_anim(delta)
		return
	st_t += delta
	_atk_cd = maxf(_atk_cd - delta, 0.0)
	_stagger_res = maxf(_stagger_res - delta, 0.0)
	if _flash > 0.0:
		_flash -= delta
		_set_flash(clampf(_flash / 0.18, 0.0, 1.0) * 0.8)
	elif state != "windup":
		_set_flash(0.0)
	var pl := _player()
	if pl == null:
		return
	_ai(delta, pl)
	_move(delta)
	_animate(delta)


func _ai(delta: float, pl: Node3D) -> void:
	var dist := _flat_to(pl.global_position).length()
	var home_d := _flat_to(home).length()
	match String(def["ai"]):
		"melee_fast": _ai_stalker(delta, pl, dist, home_d)
		"melee_heavy": _ai_brute(delta, pl, dist, home_d)
		"ranged": _ai_wraith(delta, pl, dist, home_d)
		"sentinel": _ai_sentinel(delta, pl, dist, home_d)


func _wander(delta: float) -> void:
	_wander_t -= delta
	if _wander_t <= 0.0:
		_wander_t = randf_range(2.0, 5.0)
		if randf() < 0.4:
			_wander_dir = Vector3.ZERO
		else:
			var a := randf() * TAU
			_wander_dir = Vector3(cos(a), 0, sin(a))
		if _flat_to(home).length() > 9.0:
			_wander_dir = _flat_to(home).normalized()
	_desired = _wander_dir * float(def["speed"]) * 0.28
	_face(_desired, delta, 3.0)


var _desired: Vector3 = Vector3.ZERO
var _desired_y_vel_override: bool = false


func _retreat(delta: float, pl: Node3D) -> void:
	var to_home := _flat_to(home)
	_desired = to_home.normalized() * float(def["speed"]) * 0.7
	_face(to_home, delta)
	hp = minf(hp + max_hp * 0.1 * delta, max_hp)
	if to_home.length() < 2.5:
		_enter("idle")
	elif _can_see_player(pl, 0.6) and _flat_to(home).length() < float(def["leash"]) * 0.5:
		target = pl
		_enter("chase")


func _ai_stalker(delta: float, pl: Node3D, dist: float, home_d: float) -> void:
	_desired = Vector3.ZERO
	match state:
		"idle":
			_wander(delta)
			if _can_see_player(pl):
				target = pl
				_enter("chase")
				Sfx.play_at("growl", global_position, 1.0, 45.0)
		"chase":
			if home_d > float(def["leash"]) or dist > float(def["leash"]) * 0.9 or pl.dead:
				target = null
				_enter("retreat")
				return
			var to := _flat_to(pl.global_position)
			_face(to, delta, 10.0)
			var spd := float(def["speed"])
			if dist < 5.5 and _atk_cd > 0.0:
				# circle while waiting for the next lunge
				var side := Vector3(-to.z, 0, to.x).normalized() * _strafe_dir
				_desired = (side * 0.8 + to.normalized() * 0.15).normalized() * spd * 0.6
				if st_t > 1.4:
					_strafe_dir = -_strafe_dir
					st_t = 0.0
			elif dist > float(def["range"]) + 1.2:
				_desired = to.normalized() * spd
			elif _atk_cd <= 0.0:
				_enter("windup")
		"windup":
			var to2 := _flat_to(pl.global_position)
			_face(to2, delta, 14.0)
			_set_flash(0.35 + 0.3 * sin(st_t * 30.0), Color(1.0, 0.6, 0.1))
			if st_t >= float(def["windup"]):
				_enter("attack")
				var dir := to2.normalized()
				_kb = dir * 15.0
				Sfx.play_at("growl", global_position, 1.3, 45.0)
		"attack":
			_desired = Vector3.ZERO
			if not _hit_done and dist < float(def["range"]) + 0.6 and st_t < 0.4:
				_hit_done = true
				pl.hurt(float(def["dmg"]), global_position, 7.0)
			if st_t >= 0.45:
				_atk_cd = float(def["cooldown"]) + randf() * 0.5
				_enter("chase")
		"stagger":
			if st_t > 0.45:
				_enter("chase")
		"retreat":
			_retreat(delta, pl)


func _ai_brute(delta: float, pl: Node3D, dist: float, home_d: float) -> void:
	_desired = Vector3.ZERO
	match state:
		"idle":
			_wander(delta)
			if _can_see_player(pl):
				target = pl
				_enter("chase")
				Sfx.play_at("roar", global_position, 1.0, 55.0)
		"chase":
			if home_d > float(def["leash"]) or pl.dead:
				_enter("retreat")
				return
			var to := _flat_to(pl.global_position)
			_face(to, delta, 4.0)
			if dist > float(def["range"]) * 0.9:
				_desired = to.normalized() * float(def["speed"])
			elif _atk_cd <= 0.0:
				_enter("windup")
		"windup":
			_face(_flat_to(pl.global_position), delta, 2.0)
			var f := clampf(st_t / float(def["windup"]), 0.0, 1.0)
			_set_flash(0.15 + 0.5 * f, Color(1.0, 0.3, 0.1))
			_show_indicator(float(def["range"]) + 0.6, f)
			if st_t >= float(def["windup"]):
				_enter("attack")
		"attack":
			if not _hit_done and st_t > 0.12:
				_hit_done = true
				Sfx.play_at("slam", global_position, 1.0, 60.0)
				if Game.world:
					Game.world.spawn_burst(global_position + Vector3(0, 0.2, 0) + Vector3(-sin(_facing), 0, -cos(_facing)) * 2.2, Color(0.6, 0.55, 0.5), 18, 5.0)
					pl.shake(0.5) if _flat_to(pl.global_position).length() < 16.0 else null
				var ctr := global_position + Vector3(-sin(_facing), 0, -cos(_facing)) * 1.8
				if Vector2(pl.global_position.x - ctr.x, pl.global_position.z - ctr.z).length() < float(def["range"]) + 0.6 and pl.global_position.y - global_position.y < 2.0:
					pl.hurt(float(def["dmg"]), global_position, 12.0)
			if st_t >= 0.7:
				_atk_cd = float(def["cooldown"])
				_enter("chase")
		"stagger":
			if st_t > 0.7:
				_enter("chase")
		"retreat":
			_retreat(delta, pl)


func _ai_wraith(delta: float, pl: Node3D, dist: float, home_d: float) -> void:
	_desired = Vector3.ZERO
	match state:
		"idle":
			_wander(delta)
			if _can_see_player(pl):
				target = pl
				_enter("chase")
				Sfx.play_at("wail", global_position, 1.0, 55.0)
		"chase":
			if home_d > float(def["leash"]) * 1.2 or pl.dead:
				_enter("retreat")
				return
			var to := _flat_to(pl.global_position)
			_face(to, delta, 6.0)
			var spd := float(def["speed"])
			if dist < 9.0:
				_desired = -to.normalized() * spd * 0.8
			elif dist > 17.0:
				_desired = to.normalized() * spd
			else:
				var side := Vector3(-to.z, 0, to.x).normalized() * _strafe_dir
				_desired = side * spd * 0.55
				if fmod(st_t, 2.5) < delta:
					_strafe_dir = -_strafe_dir
			if _atk_cd <= 0.0 and dist < float(def["range"]):
				_enter("windup")
		"windup":
			_face(_flat_to(pl.global_position), delta, 10.0)
			var f := clampf(st_t / float(def["windup"]), 0.0, 1.0)
			_set_flash(0.2 + 0.7 * f, Color(0.5, 0.9, 1.0))
			if st_t >= float(def["windup"]):
				_fire_volley(pl)
				_volley += 1
				Sfx.play_at("shot", global_position, 0.8, 55.0)
				if _volley >= 3:
					_volley = 0
					_enter("blink")
				else:
					_atk_cd = float(def["cooldown"]) * 0.6
					_enter("chase")
		"blink":
			if st_t < 0.25:
				model.scale = Vector3.ONE * size * maxf(1.0 - st_t * 4.0, 0.01)
			elif not _hit_done:
				_hit_done = true
				var a := randf() * TAU
				var r := randf_range(10.0, 15.0)
				var np := pl.global_position + Vector3(cos(a) * r, 0, sin(a) * r)
				np.y = WG.height_at(np.x, np.z)
				if WG.height_at(np.x, np.z) > 0.5:
					global_position = np
				Sfx.play_at("blink", global_position, 1.0, 50.0)
			else:
				model.scale = Vector3.ONE * size * minf((st_t - 0.25) * 4.0, 1.0)
			if st_t > 0.55:
				model.scale = Vector3.ONE * size
				_atk_cd = float(def["cooldown"])
				_enter("chase")
		"stagger":
			if st_t > 0.4:
				_enter("chase")
		"retreat":
			_retreat(delta, pl)


func _fire_volley(pl: Node3D) -> void:
	if Game.world == null:
		return
	var o := global_position + Vector3(0, 2.1 * size, 0)
	var tgt: Vector3 = pl.global_position + Vector3(0, 1.1, 0) + Vector3(pl.velocity.x, 0, pl.velocity.z) * 0.35
	var dir := (tgt - o).normalized()
	Game.world.spawn_projectile(o, dir, float(def["dmg"]), false, 17.0, Color(0.75, 0.5, 1.0), self)


func _ai_sentinel(delta: float, pl: Node3D, dist: float, home_d: float) -> void:
	_desired = Vector3.ZERO
	_guard = false
	if not _booted:
		if dist < 15.0 and not pl.dead:
			_booted = true
			_enter("boot")
			Sfx.play_at("machine_on", global_position, 1.0, 50.0)
		else:
			return
	match state:
		"boot":
			if st_t > 1.2:
				target = pl
				_enter("chase")
		"idle":
			_wander(delta)
			if _can_see_player(pl):
				target = pl
				_enter("chase")
		"chase":
			if home_d > float(def["leash"]) or pl.dead:
				_enter("retreat")
				return
			var to := _flat_to(pl.global_position)
			_face(to, delta, 5.0)
			if dist > float(def["range"]) + 0.5:
				_desired = to.normalized() * float(def["speed"])
				_guard = dist < 8.0
			elif _atk_cd <= 0.0:
				_enter("windup")
			else:
				_guard = true
		"windup":
			_face(_flat_to(pl.global_position), delta, 3.0)
			_set_flash(0.2 + 0.4 * sin(st_t * 14.0), Color(1.0, 0.35, 0.2))
			if st_t >= float(def["windup"]):
				_enter("attack")
				Sfx.play_at("swing_heavy", global_position, 0.7, 50.0)
		"attack":
			if not _hit_done and st_t > 0.15 and st_t < 0.4:
				var fwd := Vector3(-sin(_facing), 0, -cos(_facing))
				var to3 := _flat_to(pl.global_position)
				if to3.length() < float(def["range"]) + 0.8 and fwd.dot(to3.normalized()) > 0.1:
					_hit_done = true
					pl.hurt(float(def["dmg"]), global_position, 8.0)
					Sfx.play_at("hit_metal", global_position, 0.8, 40.0)
			if st_t > 0.7:
				_atk_count += 1
				_atk_cd = float(def["cooldown"])
				_enter("chase")
		"stagger":
			if st_t > 0.5:
				_enter("chase")
		"retreat":
			_retreat(delta, pl)


func _show_indicator(radius: float, f: float) -> void:
	if _indicator == null:
		_indicator = MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 1.0
		cm.bottom_radius = 1.0
		cm.height = 0.05
		cm.radial_segments = 24
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(1.0, 0.2, 0.1, 0.35)
		cm.material = m
		_indicator.mesh = cm
		_indicator.top_level = true
		add_child(_indicator)
	var ctr := global_position + Vector3(-sin(_facing), 0, -cos(_facing)) * 1.8
	_indicator.global_position = Vector3(ctr.x, WG.height_at(ctr.x, ctr.z) + 0.08, ctr.z)
	_indicator.scale = Vector3(radius, 1.0, radius) * (0.3 + 0.7 * f)
	(_indicator.mesh.material as StandardMaterial3D).albedo_color.a = 0.2 + 0.3 * f


# ----------------------------------------------------------------- movement
func _move(delta: float) -> void:
	var v := _desired
	if state in ["windup", "stagger", "boot", "blink"] and String(def["ai"]) != "ranged":
		v = Vector3.ZERO
	if state == "windup" and String(def["ai"]) == "ranged":
		v = Vector3.ZERO
	var hv := Vector3(velocity.x, 0, velocity.z)
	hv = hv.move_toward(v, 30.0 * delta)
	if _kb.length() > 0.1:
		hv += _kb
		_kb = Vector3.ZERO
	velocity.x = hv.x
	velocity.z = hv.z
	if String(def["ai"]) == "ranged":
		var gh := WG.height_at(global_position.x, global_position.z)
		var want := maxf(gh, 0.0) + 1.3 + sin(Time.get_ticks_msec() * 0.003 + float(get_instance_id() % 10)) * 0.25
		velocity.y = (want - global_position.y) * 4.0
	else:
		if not is_on_floor():
			velocity.y -= 24.0 * delta
		else:
			velocity.y = -1.0
	move_and_slide()
	rotation.y = _facing
	# keep to land
	var gh2 := WG.height_at(global_position.x, global_position.z)
	if gh2 < -0.2 and String(def["ai"]) != "ranged":
		global_position = global_position.lerp(home, 0.2)
	if global_position.y < gh2 - 3.0:
		global_position.y = gh2 + 1.0


# ----------------------------------------------------------------- animation
func _animate(delta: float) -> void:
	var spd := Vector3(velocity.x, 0, velocity.z).length()
	_walk_phase += delta * (4.0 + spd * 1.1)
	var sw := sin(_walk_phase) * clampf(spd / 3.0, 0.0, 1.0) * 0.8
	var ai := String(def["ai"])
	var t := st_t
	match ai:
		"melee_fast":
			_rot("leg0", sw, 0, 0); _rot("leg3", sw, 0, 0)
			_rot("leg1", -sw, 0, 0); _rot("leg2", -sw, 0, 0)
			var crouch := 0.0
			if state == "windup":
				crouch = clampf(t / float(def["windup"]), 0.0, 1.0)
			if state == "attack":
				crouch = -0.5
			_rot("body", crouch * 0.35 - (0.2 if state == "attack" else 0.0), 0, 0)
			_move_y("body", 0.78 - crouch * 0.25)
			_rot("head", -crouch * 0.4 + (0.3 if state == "stagger" else 0.0), 0, 0)
		"melee_heavy":
			_rot("leg0", sw, 0, 0); _rot("leg1", -sw, 0, 0)
			var raise := 0.0
			if state == "windup":
				raise = clampf(t / float(def["windup"]), 0.0, 1.0)
			elif state == "attack":
				raise = 1.0 - clampf(t / 0.2, 0.0, 1.0)
			_rot("arm0", -raise * 2.7 + sw * 0.4 * (1.0 - raise), 0, 0.1)
			_rot("arm1", -raise * 2.7 - sw * 0.4 * (1.0 - raise), 0, -0.1)
			_rot("body", raise * -0.25 + (0.5 * clampf(1.0 - t / 0.25, 0.0, 1.0) if state == "attack" else 0.0), 0, 0)
		"ranged":
			_rot("ring", 0, delta * 1.5 + 0.0, 0, true)
			_rot("body", 0, 0, 0)
			var pulse := 1.0 + 0.15 * sin(Time.get_ticks_msec() * 0.008)
			if state == "windup":
				pulse = 1.0 + 0.5 * clampf(t / float(def["windup"]), 0.0, 1.0)
			if pivots.has("core"):
				pivots["core"].scale = Vector3.ONE * pulse
			_rot("body", 0.0, 0.0, sin(Time.get_ticks_msec() * 0.002) * 0.05)
		"sentinel":
			_rot("leg0", sw * 0.7, 0, 0); _rot("leg1", -sw * 0.7, 0, 0)
			var up := 0.0
			if state == "windup":
				up = clampf(t / float(def["windup"]), 0.0, 1.0)
			elif state == "attack":
				up = 1.0 - clampf(t / 0.25, 0.0, 1.0)
			var gd := -1.6 if _guard else 0.0
			_rot("arm0", -up * 2.4 + gd * 0.6 + sw * 0.3, 0, 0)
			_rot("arm1", -up * 2.4 + gd * 0.6 - sw * 0.3, 0, 0)
			var bt := 1.0 if _booted else 0.0
			_move_y("head", 2.5 - (1.0 - bt) * 0.5)
			if not _booted:
				_rot("body", 0.35, 0, 0)
			else:
				_rot("body", 0, 0, 0)


func _rot(pname: String, x: float, y: float, z: float, additive: bool = false) -> void:
	if not pivots.has(pname):
		return
	var n: Node3D = pivots[pname]
	if additive:
		n.rotation.y += y
	else:
		n.rotation = n.rotation.lerp(Vector3(x, y, z), 0.35)


func _move_y(pname: String, y: float) -> void:
	if pivots.has(pname):
		pivots[pname].position.y = lerpf(pivots[pname].position.y, y, 0.3)


func _dead_anim(delta: float) -> void:
	st_t += delta
	var f := clampf(st_t / 1.2, 0.0, 1.0)
	model.rotation.z = lerpf(0.0, PI * 0.5, minf(f * 2.0, 1.0)) * (1.0 if String(def["ai"]) != "ranged" else 0.0)
	model.position.y = -f * 0.3 if String(def["ai"]) != "ranged" else -f * 1.3
	if String(def["ai"]) == "ranged":
		model.scale = Vector3.ONE * size * (1.0 - f)
	if f >= 1.0:
		queue_free()
