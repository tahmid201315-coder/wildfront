extends Node3D
## One Wildling in the world: wild (befriendable), companion (follows the player) or hostile (Rustmaw).
## Simple, testable state machines. AI update rate drops with distance from the player.

const CM = preload("res://scripts/creatures/creature_model.gd")

var world: Node = null
var species: String = ""
var def: Dictionary = {}
var spawn_id: String = ""
var is_companion: bool = false
var companion_uid: String = ""
var hostile: bool = false

var state: String = "idle"
var home: Vector3 = Vector3.ZERO
var goal: Vector3 = Vector3.ZERO
var timer: float = 1.0
var model: Node3D
var hp: float = 10.0
var max_hp: float = 10.0
var trust: float = 0.0
var interact_radius: float = 3.4

var _t: float = 0.0
var _acc: float = 0.0
var _speed_now: float = 0.0
var _anim_state: String = ""
var _anim_timer: float = 0.0
var _stuck: float = 0.0
var _label: Label3D
var _label_t: float = 0.0
var _observe_t: float = 0.0
var _water_ok: bool = false
var _atk_cd: float = 0.0
var _noticed_player: bool = false

# hostile / boss
var atk_state: String = "idle"
var atk_t: float = 0.0
var atk_target: Vector3 = Vector3.ZERO
var atk_dir: Vector3 = Vector3.ZERO
var atk_cool: float = 1.5
var phase: int = 1
var _hit_done: bool = false
var _tele: MeshInstance3D
var engaged: bool = false


func setup(p_world: Node, p_species: String, pos: Vector3, p_spawn_id: String = "", companion: bool = false) -> void:
	world = p_world
	species = p_species
	def = Data.creatures[species]
	spawn_id = p_spawn_id
	is_companion = companion
	hostile = bool(def.get("hostile", false))
	_water_ok = bool(def.get("water_ok", false))
	max_hp = float(def["hp"])
	hp = max_hp
	if companion:
		var c := Game.active_creature()
		if not c.is_empty():
			companion_uid = c["uid"]
			max_hp = Game.creature_max_hp(c)
			hp = max_hp
	model = CM.build(species)
	add_child(model)
	position = Vector3(pos.x, world.height_at(pos.x, pos.z), pos.z)
	home = position
	goal = position
	_t = randf() * 10.0
	timer = randf_range(0.5, 3.0)
	if hostile:
		add_to_group("hostile")
		add_to_group("creature")
		interact_radius = 0.0
	elif companion:
		add_to_group("companion")
	else:
		add_to_group("interactable")
		add_to_group("creature")
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.012
	_label.font_size = 36
	_label.outline_size = 10
	_label.position = Vector3(0, 2.4 * float(def.get("scale", 1.0)) + 0.4, 0)
	_label.no_depth_test = true
	_label.visible = false
	add_child(_label)


# ------------------------------------------------------------ interactable (wild only)
func _best_offer() -> String:
	var fav: String = def.get("food", "")
	if fav != "" and Inv.count(fav) > 0:
		return fav
	for f in def.get("foods", []):
		if Inv.count(f) > 0:
			return f
	if Inv.count("treat") > 0:
		return "treat"
	return ""


func get_prompt() -> String:
	if hostile or is_companion:
		return ""
	var offer := _best_offer()
	if offer == "":
		return "%s (needs %s)" % [def["name"], Data.item_name(def.get("food", "berries"))]
	return "Offer %s to %s" % [Data.item_name(offer), def["name"]]


func can_interact(_player: Node) -> bool:
	return not hostile and not is_companion


func interact(player: Node) -> void:
	if hostile or is_companion:
		return
	var offer := _best_offer()
	if offer == "":
		Game.toast("%s likes %s. Bring some!" % [def["name"], Data.item_name(def.get("food", "berries"))], "info")
		Sfx.play("invalid")
		_react("puff")
		return
	if not Inv.remove(offer, 1):
		return
	var gain := 15.0
	var favorite: bool = offer == str(def.get("food", ""))
	if favorite:
		gain = 30.0
	if offer == "treat":
		gain = 40.0
	trust = minf(trust + gain, 100.0)
	_react("happy")
	Sfx.play_voice(species)
	if player.has_method("begin_interact"):
		player.begin_interact()
	var need := float(def["difficulty"])
	var pct := int(clampf(trust / need * 100.0, 0.0, 100.0))
	_show_label("Trust %d%%" % pct, 3.0)
	if trust >= need:
		var chance := clampf(0.6 + (trust - need) * 0.01 + (0.2 if favorite else 0.0), 0.5, 0.95)
		if Game.creatures.is_empty() or randf() < chance:
			world.befriend(self)
		else:
			trust = maxf(trust - 8.0, 0.0)
			Game.toast("%s is still unsure. Keep trying." % def["name"], "info")
			_react("puff")
	else:
		Game.toast("%s seems to like it! (Trust %d%%)" % [def["name"], pct], "info")


func _show_label(text: String, secs: float) -> void:
	_label.text = text
	_label.visible = true
	_label_t = secs


func _react(s: String) -> void:
	_anim_state = s
	_anim_timer = 1.2


# ------------------------------------------------------------ main loop
func _process(delta: float) -> void:
	if world == null or world.player == null:
		return
	_t += delta
	if _label_t > 0.0:
		_label_t -= delta
		if _label_t <= 0.0:
			_label.visible = false
	if _anim_timer > 0.0:
		_anim_timer -= delta
		if _anim_timer <= 0.0:
			_anim_state = ""
	var ppos: Vector3 = world.player.global_position
	var dist: float = global_position.distance_to(ppos)
	var interval := 0.0
	if not is_companion:
		interval = 0.0 if dist < 28.0 else (0.15 if dist < 55.0 else 0.6)
	_acc += delta
	if _acc >= interval:
		var dt := _acc
		_acc = 0.0
		_ai(dt, dist, ppos)
	if dist < 55.0 or is_companion:
		CM.animate(model, _t, _speed_now, _anim_state)
	_speed_now = lerpf(_speed_now, 0.0, minf(1.0, delta * 6.0))


func _ai(dt: float, dist: float, ppos: Vector3) -> void:
	_atk_cd = maxf(_atk_cd - dt, 0.0)
	if is_companion:
		_companion_ai(dt, dist, ppos)
	elif hostile:
		_hostile_ai(dt, dist, ppos)
	else:
		_wild_ai(dt, dist, ppos)


# ------------------------------------------------------------ wild behaviour
func _wild_ai(dt: float, dist: float, ppos: Vector3) -> void:
	var temper: String = def["temperament"]
	var pspeed: float = world.player.speed_xz
	if dist < 16.0 and not Game.discovered_species.has(species):
		Game.discover_species(species)
	# trust slowly fades if the player ignores the creature, and patient observation helps
	if dist > 12.0:
		trust = maxf(trust - dt * 0.4, 0.0)
	elif dist < 7.0 and pspeed < 0.5 and trust < float(def["difficulty"]) * 0.5:
		_observe_t += dt
		if _observe_t > 4.0:
			_observe_t = 0.0
			trust += 4.0
			_show_label("Trust %d%%" % int(trust / float(def["difficulty"]) * 100.0), 2.0)
	else:
		_observe_t = 0.0

	# reactions
	if temper == "skittish" and state != "flee" and dist < 9.0 and (pspeed > 5.5 or dist < 4.0):
		state = "flee"
		timer = 4.0
		Sfx.play_voice(species)
	elif temper == "curious" and state in ["idle", "wander"] and dist < 13.0 and dist > 4.0 and randf() < 0.05:
		state = "approach"
		timer = 6.0
	elif temper in ["docile", "territorial"] and dist < 7.0 and state in ["idle", "wander"]:
		state = "notice"
		timer = 3.0

	match state:
		"idle":
			timer -= dt
			if timer <= 0.0:
				_pick_wander_goal()
				state = "wander"
		"wander":
			if _step_toward(goal, float(def["speed"]) * 0.6, dt) or _stuck > 1.0:
				state = "idle"
				timer = randf_range(1.5, 4.5)
				_stuck = 0.0
		"notice":
			_face(ppos - global_position, dt, 6.0)
			if temper == "territorial":
				_anim_state = "puff" if dist < 5.0 else ""
			timer -= dt
			if timer <= 0.0 or dist > 9.0:
				state = "idle"
				timer = randf_range(1.0, 3.0)
				_anim_state = ""
		"approach":
			timer -= dt
			if dist > 3.0:
				_step_toward(ppos, float(def["speed"]), dt)
			if timer <= 0.0 or dist <= 3.0:
				state = "idle"
				timer = 3.0
		"flee":
			var away := global_position - ppos
			away.y = 0.0
			if away.length() < 0.01:
				away = Vector3(1, 0, 0)
			_step_toward(global_position + away.normalized() * 6.0, float(def["speed"]) * 1.5, dt)
			timer -= dt
			if timer <= 0.0 and dist > 14.0:
				state = "idle"
				timer = 2.0
			elif _stuck > 0.8:
				# cornered: sidestep instead of freezing
				goal = global_position + away.normalized().rotated(Vector3.UP, 1.5) * 4.0
				_step_toward(goal, float(def["speed"]), dt)
				_stuck = 0.0
	# keep roughly near home
	if global_position.distance_to(home) > 18.0 and state == "wander":
		goal = home


func _pick_wander_goal() -> void:
	for i in 6:
		var a := randf() * TAU
		var r := randf_range(2.0, 8.0)
		var g := home + Vector3(cos(a) * r, 0, sin(a) * r)
		if world.can_walk(g, _water_ok):
			goal = g
			return
	goal = home


# ------------------------------------------------------------ companion behaviour
func _companion_ai(dt: float, dist: float, ppos: Vector3) -> void:
	var pl: Node = world.player
	# fight alongside the player
	var target: Node = world.nearest_hostile(ppos, 14.0)
	if target != null and state != "return":
		var tpos: Vector3 = target.global_position
		var td := global_position.distance_to(tpos)
		if td > 2.6 * float(def.get("scale", 1.0)):
			_step_toward(tpos, float(def["speed"]) * 1.8, dt)
		else:
			_face(tpos - global_position, dt, 10.0)
			if _atk_cd <= 0.0:
				_atk_cd = 1.8
				var c := Game.find_creature(companion_uid)
				var lv := int(c.get("level", 1)) if not c.is_empty() else 1
				target.take_damage(float(def["atk"]) * (1.0 + 0.15 * (lv - 1)) + 2.0, "companion")
				_react("attack")
				Sfx.play("hit", 1.2, -6.0)
				Game.creature_add_xp(companion_uid, 2)
		return
	# follow: stand beside-behind the player
	var yaw: float = pl.facing_yaw
	var behind := Vector3(sin(yaw), 0, cos(yaw))  # opposite of player's forward
	var side := Vector3(cos(yaw), 0, -sin(yaw))
	var hold := ppos + behind * 2.2 + side * 1.4
	var d_hold := global_position.distance_to(hold)
	if dist > 30.0 or _stuck > 3.0:
		_teleport_to(hold)
		return
	if d_hold > 1.3:
		var spd := maxf(float(def["speed"]), pl.speed_xz * 1.15 + 0.5)
		if dist > 14.0:
			spd *= 1.6
		_step_toward(hold, spd, dt)
	else:
		_face(ppos - global_position, dt, 3.0)
		_stuck = 0.0


func _teleport_to(p: Vector3) -> void:
	for off in [Vector3.ZERO, Vector3(2, 0, 0), Vector3(-2, 0, 0), Vector3(0, 0, 2), Vector3(0, 0, -2)]:
		var q: Vector3 = p + off
		if world.can_walk(q, true):
			global_position = Vector3(q.x, world.height_at(q.x, q.z), q.z)
			_stuck = 0.0
			return
	var pp: Vector3 = world.player.global_position
	global_position = Vector3(pp.x + 1.5, world.height_at(pp.x + 1.5, pp.z), pp.z)
	_stuck = 0.0


# ------------------------------------------------------------ hostile / boss behaviour
func take_damage(amount: float, _src: String = "") -> void:
	if not hostile or hp <= 0.0:
		return
	hp -= amount
	engaged = true
	if atk_state == "idle":
		atk_state = "chase"
	_react("attack")
	var tw := create_tween()
	tw.tween_property(model, "scale", model.scale * 1.12, 0.06)
	tw.tween_property(model, "scale", Vector3.ONE * float(def.get("scale", 1.0)), 0.1)
	if world:
		world.float_text(global_position + Vector3(0, 3.0, 0), "-%d" % int(amount), Color(1, 0.8, 0.3))
		world.spawn_burst(global_position + Vector3(0, 1.5, 0), Color(1, 0.6, 0.2), 8)
	if phase == 1 and hp <= max_hp * 0.5 and hp > 0.0:
		phase = 2
		Sfx.play("boss_phase")
		Game.toast("The %s is enraged!" % def["name"], "warn")
		if world:
			world.spawn_burst(global_position + Vector3(0, 2.0, 0), Color(1, 0.3, 0.1), 24)
	_update_hp_label()
	if hp <= 0.0:
		_die()


func _update_hp_label() -> void:
	var frac := clampf(hp / max_hp, 0.0, 1.0)
	var n := int(round(frac * 10.0))
	_label.text = "%s [%s%s]" % [def["name"], "#".repeat(n), "-".repeat(10 - n)]
	_label.visible = true
	_label_t = 99.0


func _die() -> void:
	Sfx.play_voice(species)
	if world:
		world.on_hostile_defeated(self)
	queue_free()


func _make_tele(radius: float) -> void:
	_clear_tele()
	_tele = MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = 1.0
	m.bottom_radius = 1.0
	m.height = 0.06
	m.radial_segments = 24
	_tele.mesh = m
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color(1.0, 0.15, 0.1, 0.55)
	mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.emission_enabled = true
	mt.emission = Color(1.0, 0.2, 0.1)
	_tele.material_override = mt
	_tele.top_level = true
	_tele.scale = Vector3(radius, 1, radius)
	add_child(_tele)


func _clear_tele() -> void:
	if _tele != null and is_instance_valid(_tele):
		_tele.queue_free()
	_tele = null


func _hostile_ai(dt: float, dist: float, ppos: Vector3) -> void:
	var pl: Node = world.player
	atk_cool -= dt
	match atk_state:
		"idle":
			if dist < 18.0 and pl.is_alive():
				atk_state = "chase"
				engaged = true
				Sfx.play_voice(species)
				Game.toast("The %s notices you!" % def["name"], "warn")
				Sfx.play_music("boss")
				_update_hp_label()
			else:
				_anim_state = ""
		"chase":
			if not pl.is_alive() or dist > 42.0:
				_reset_encounter()
				return
			var spd := float(def["speed"]) * (1.25 if phase == 2 else 1.0)
			if dist > 5.0:
				_step_toward(ppos, spd, dt)
			else:
				_face(ppos - global_position, dt, 8.0)
			if atk_cool <= 0.0 and dist < 12.0:
				if phase == 2 and dist > 5.5 and randf() < 0.5:
					_start_rush(ppos)
				else:
					_start_slam(ppos)
		"tele_slam":
			atk_t -= dt
			var k := 1.0 - clampf(atk_t / 1.1, 0.0, 1.0)
			if _tele:
				_tele.global_position = Vector3(atk_target.x, world.height_at(atk_target.x, atk_target.z) + 0.08, atk_target.z)
				_tele.scale = Vector3(3.3 * (0.35 + 0.65 * k), 1, 3.3 * (0.35 + 0.65 * k))
			if atk_t <= 0.0:
				_clear_tele()
				if pl.global_position.distance_to(atk_target) < 3.3 and pl.is_alive():
					pl.hurt(float(def["atk"]), self)
				world.spawn_burst(atk_target + Vector3(0, 0.5, 0), Color(0.9, 0.6, 0.3), 14)
				world.shake_camera(0.25)
				Sfx.play("hit", 0.7)
				atk_state = "recover"
				atk_t = 0.9
				atk_cool = 1.0 if phase == 2 else 2.2
		"tele_rush":
			atk_t -= dt
			_face(atk_dir, dt, 12.0)
			var k2 := 1.0 - clampf(atk_t / 0.9, 0.0, 1.0)
			if _tele:
				var mid := global_position + atk_dir * 5.0
				_tele.global_position = Vector3(mid.x, world.height_at(mid.x, mid.z) + 0.1, mid.z)
				_tele.global_rotation = Vector3(0, atan2(atk_dir.x, atk_dir.z), 0)
				_tele.scale = Vector3(1.3 * (0.4 + 0.6 * k2), 1, 5.0)
			if atk_t <= 0.0:
				_clear_tele()
				atk_state = "rush"
				atk_t = 0.4
				_hit_done = false
				_anim_state = "attack"
		"rush":
			atk_t -= dt
			var step := atk_dir * 22.0 * dt
			var np := global_position + step
			if world.can_walk(np, false):
				global_position = Vector3(np.x, world.height_at(np.x, np.z), np.z)
			if not _hit_done and pl.is_alive() and global_position.distance_to(pl.global_position) < 2.3:
				_hit_done = true
				pl.hurt(float(def["atk"]) * 1.2, self)
				world.shake_camera(0.3)
				Sfx.play("hit", 0.6)
			if atk_t <= 0.0:
				atk_state = "recover"
				atk_t = 1.3
				atk_cool = 1.2
				_anim_state = ""
		"recover":
			atk_t -= dt
			if atk_t <= 0.0:
				atk_state = "chase"
	if atk_state in ["chase", "recover", "tele_slam", "tele_rush", "rush"]:
		_speed_now = maxf(_speed_now, 1.0) if atk_state == "chase" else _speed_now


func _start_slam(ppos: Vector3) -> void:
	atk_state = "tele_slam"
	atk_t = 1.1
	atk_target = ppos
	_make_tele(3.3)
	Sfx.play("telegraph")


func _start_rush(ppos: Vector3) -> void:
	atk_state = "tele_rush"
	atk_t = 0.9
	atk_dir = (ppos - global_position)
	atk_dir.y = 0.0
	atk_dir = atk_dir.normalized()
	_make_tele(1.3)
	Sfx.play("telegraph", 1.3)


func _reset_encounter() -> void:
	atk_state = "idle"
	engaged = false
	hp = max_hp
	phase = 1
	_clear_tele()
	_anim_state = ""
	global_position = home
	_label.visible = false
	Sfx.play_music("ember" if Data.region_at(global_position.x, 0) == "ember" else "explore")


# ------------------------------------------------------------ movement helpers
## Moves toward a point on the ground. Returns true when arrived.
func _step_toward(target: Vector3, speed: float, dt: float) -> bool:
	var to := target - global_position
	to.y = 0.0
	var d := to.length()
	if d < 0.35:
		return true
	var dir := to / d
	var step := minf(speed * dt, d)
	var next := global_position + dir * step
	if not world.can_walk(next, _water_ok or is_companion):
		var found := false
		for ang in [0.6, -0.6, 1.2, -1.2, 1.9, -1.9]:
			var d2: Vector3 = dir.rotated(Vector3.UP, ang)
			var n2: Vector3 = global_position + d2 * step
			if world.can_walk(n2, _water_ok or is_companion):
				next = n2
				dir = d2
				found = true
				break
		if not found:
			_stuck += dt
			return false
	_stuck = maxf(_stuck - dt * 0.5, 0.0)
	global_position = Vector3(next.x, world.height_at(next.x, next.z), next.z)
	_speed_now = speed
	_face(dir, dt, 10.0)
	return false


func _face(dir: Vector3, dt: float, rate: float) -> void:
	if dir.length_squared() < 0.0001:
		return
	var yaw := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, yaw, minf(1.0, rate * dt))
