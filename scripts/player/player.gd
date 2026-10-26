extends CharacterBody3D
## Third-person player controller: movement, swimming, combat, gathering, survival and camera rig.

const WG = preload("res://scripts/world/world_gen.gd")
const DW = preload("res://scripts/core/data_world.gd")
const PlayerModel = preload("res://scripts/player/player_model.gd")

signal died

# --- tuning
const WALK_SPEED := 3.1
const RUN_SPEED := 5.4
const SPRINT_SPEED := 8.0
const CROUCH_SPEED := 2.0
const SWIM_SPEED := 3.2
const JUMP_VELOCITY := 8.6
const GRAVITY := 24.0
const SPRINT_COST := 13.0
const JUMP_COST := 8.0

var touch: Control = null
var world: Node = null
var model: Node3D
var cam_rig: Node3D
var arm: SpringArm3D
var cam: Camera3D

# camera
var cam_yaw: float = 0.0
var cam_pitch: float = -0.28
var cam_dist: float = 5.4
var _cam_dist_now: float = 5.4
var _shake: float = 0.0

# input state set by HUD buttons / keyboard
var sprint_held: bool = false
var crouch_on: bool = false
var attack_held: bool = false
var interact_held: bool = false
var _jump_buf: float = 0.0
var _atk_buf: float = 0.0
var _dodge_buf: float = 0.0
var _attack_hold_t: float = 0.0

# motion
var facing_yaw: float = 0.0
var swimming: bool = false
var grounded: bool = false
var _coyote: float = 0.0
var _air_time: float = 0.0
var _fall_peak_y: float = 0.0
var speed_xz: float = 0.0
var _land_t: float = 0.0
var _step_t: float = 0.0
var _stuck_t: float = 0.0
var _stuck_ref: Vector3 = Vector3.ZERO

# action state
var action: String = ""            # "", attack, gather, dodge, interact, hurt
var _action_t: float = 0.0
var _action_len: float = 0.0
var _atk_kind: String = ""
var _atk_chain: int = 0
var _atk_chain_t: float = 0.0
var _hit_set: Dictionary = {}
var _atk_dmg_mult: float = 1.0
var _gather_target: Node = null
var _gather_did: bool = false
var _dodge_dir: Vector3 = Vector3.ZERO
var invuln: float = 0.0
var dodge_cd: float = 0.0
var _ammo_charge: int = 0

# survival
var _stamina_delay: float = 0.0
var _out_of_combat: float = 10.0
var _warn_cd: float = 0.0
var dead: bool = false
var current_region: String = "coast"

# interaction
var prompt_text: String = ""
var prompt_target: Node = null
var _scan_t: float = 0.0
var held_tool_hint: String = ""


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2
	floor_max_angle = deg_to_rad(54.0)
	floor_snap_length = 0.55
	floor_stop_on_slope = true
	floor_constant_speed = true
	up_direction = Vector3.UP
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.36
	cap.height = 1.76
	cs.shape = cap
	cs.position.y = 0.88
	add_child(cs)
	model = PlayerModel.new()
	model.name = "Model"
	add_child(model)
	cam_rig = Node3D.new()
	cam_rig.top_level = true
	add_child(cam_rig)
	arm = SpringArm3D.new()
	arm.spring_length = cam_dist
	arm.collision_mask = 1 | 2
	arm.margin = 0.25
	var sph := SphereShape3D.new()
	sph.radius = 0.22
	arm.shape = sph
	cam_rig.add_child(arm)
	cam = Camera3D.new()
	cam.fov = 68.0
	cam.near = 0.12
	cam.far = 520.0
	arm.add_child(cam)
	Game.equipment_changed.connect(_on_equipment_changed)
	Inv.changed.connect(_refresh_held_tool)
	_fall_peak_y = global_position.y


func _on_equipment_changed() -> void:
	model.rebuild_equipment()


func place_at(p: Vector3) -> void:
	global_position = p
	velocity = Vector3.ZERO
	_fall_peak_y = p.y
	cam_rig.global_position = p + Vector3(0, 1.5, 0)
	_stuck_ref = p


# ----------------------------------------------------------------- input API (HUD / keyboard)
func apply_look(rel: Vector2) -> void:
	var sens := float(Game.settings["cam_sens"]) * 0.0042
	cam_yaw -= rel.x * sens
	var inv := -1.0 if bool(Game.settings["cam_invert"]) else 1.0
	cam_pitch = clampf(cam_pitch - rel.y * sens * inv, -1.15, 0.55)


func apply_zoom(amount: float) -> void:
	cam_dist = clampf(cam_dist + amount, 2.6, 9.0)


func request_jump() -> void:
	_jump_buf = 0.14


func request_dodge() -> void:
	_dodge_buf = 0.2


func toggle_crouch() -> void:
	crouch_on = not crouch_on


func attack_down() -> void:
	attack_held = true
	_attack_hold_t = 0.0
	if not Game.has_skill("cb3"):
		_atk_buf = 0.25


func attack_up() -> void:
	if not attack_held:
		return
	attack_held = false
	if Game.has_skill("cb3"):
		if _attack_hold_t >= 0.45:
			_try_attack(true)
		else:
			_atk_buf = 0.25


func interact_down() -> void:
	interact_held = true
	_do_interact(false)


func interact_up() -> void:
	interact_held = false


func _move_input() -> Vector2:
	var v := Vector2.ZERO
	if touch != null and touch.move_vec != Vector2.ZERO:
		v = touch.move_vec
	else:
		v = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	return v


# ----------------------------------------------------------------- main loop
func _physics_process(delta: float) -> void:
	if dead:
		model.state = "death"
		model.phase_t += delta
		model.animate(delta)
		_update_camera(delta)
		return
	if not Game.is_playing():
		return
	Game.play_seconds += delta
	_tick_timers(delta)
	_poll_keyboard()
	_environment(delta)
	_actions(delta)
	_movement(delta)
	_step_up()
	move_and_slide()
	_post_move(delta)
	_survival(delta)
	_scan_interactables(delta)
	_update_model(delta)
	_update_camera(delta)
	if world:
		world.player_moved(global_position)


func _poll_keyboard() -> void:
	if Input.is_action_just_pressed("jump"):
		request_jump()
	if Input.is_action_just_pressed("dodge"):
		request_dodge()
	if Input.is_action_just_pressed("act"):
		interact_down()
	if Input.is_action_just_released("act"):
		interact_up()
	if Input.is_action_just_pressed("attack"):
		attack_down()
	if Input.is_action_just_released("attack"):
		attack_up()
	if Input.is_key_pressed(KEY_SHIFT):
		sprint_held = true
	elif touch == null or touch.move_vec == Vector2.ZERO:
		if not _sprint_from_touch:
			sprint_held = false


var _sprint_from_touch: bool = false


func set_sprint(v: bool) -> void:
	_sprint_from_touch = v
	sprint_held = v


func _tick_timers(delta: float) -> void:
	_jump_buf = maxf(_jump_buf - delta, 0.0)
	_atk_buf = maxf(_atk_buf - delta, 0.0)
	_dodge_buf = maxf(_dodge_buf - delta, 0.0)
	invuln = maxf(invuln - delta, 0.0)
	dodge_cd = maxf(dodge_cd - delta, 0.0)
	_land_t = maxf(_land_t - delta, 0.0)
	_atk_chain_t = maxf(_atk_chain_t - delta, 0.0)
	_out_of_combat += delta
	_warn_cd = maxf(_warn_cd - delta, 0.0)
	if attack_held:
		_attack_hold_t += delta
	if _atk_chain_t <= 0.0:
		_atk_chain = 0


# ----------------------------------------------------------------- environment
func _environment(_delta: float) -> void:
	var p := global_position
	var h := WG.height_at(p.x, p.z)
	var depth := -h                         # water depth at this x,z (water surface y = 0)
	var was := swimming
	swimming = depth > 1.25 and p.y < 0.35
	if swimming != was:
		if swimming:
			Sfx.play("splash")
			_spawn_splash()
		velocity.y *= 0.3
	if depth > 4.5:
		# open ocean: the current pushes the explorer back towards land
		var to_land := (Vector3(0, 0, 0) - Vector3(p.x, 0, p.z)).normalized()
		velocity += to_land * 14.0 * _delta
		if _warn_cd <= 0.0:
			Game.toast("The current is too strong. Turn back.", "warn")
			_warn_cd = 4.0
	var reg := WG.region_at(p.x, p.z)
	if reg != current_region:
		current_region = reg
		Game.enter_region(reg)
	if world:
		world.player_region = current_region


func _spawn_splash() -> void:
	if world and world.has_method("spawn_burst"):
		world.spawn_burst(global_position + Vector3(0, 0.2, 0), Color(0.8, 0.95, 1.0), 14, 3.0)


# ----------------------------------------------------------------- actions
func _actions(delta: float) -> void:
	if action != "":
		_action_t += delta
		match action:
			"attack":
				_update_attack()
			"gather":
				_update_gather()
		if _action_t >= _action_len:
			var was := action
			action = ""
			if was == "attack":
				_atk_chain_t = 0.55
			if was == "gather" and interact_held and _gather_target and is_instance_valid(_gather_target) and _gather_target.hold_repeat and _gather_target.can_interact(self):
				_start_gather(_gather_target)
		model.phase_t = _action_t
	if action == "" or action == "attack" and _action_t > _action_len * 0.7:
		if _dodge_buf > 0.0:
			_try_dodge()
		if _atk_buf > 0.0 and action == "":
			_try_attack(false)
	elif action == "gather" and _dodge_buf > 0.0:
		action = ""
		_try_dodge()
	if _attack_held_chain():
		_try_attack(false)


func _attack_held_chain() -> bool:
	return false


func _try_dodge() -> void:
	if dodge_cd > 0.0 or swimming or not grounded and _air_time > 0.2:
		return
	var cost := 20.0 * (0.65 if Game.has_skill("cb2") else 1.0)
	if Game.stamina < cost:
		_dodge_buf = 0.0
		if _warn_cd <= 0.0:
			Game.toast("Not enough stamina.", "warn")
			_warn_cd = 1.5
		return
	_dodge_buf = 0.0
	_atk_buf = 0.0
	Game.stamina -= cost
	_stamina_delay = 1.0
	var mv := _move_input()
	var yaw := cam_yaw
	var dir := Vector3.ZERO
	if mv.length() > 0.2:
		dir = (Basis(Vector3.UP, yaw) * Vector3(mv.x, 0, mv.y)).normalized()
	else:
		dir = -Vector3(sin(facing_yaw), 0, cos(facing_yaw))   # back-step
		dir = Vector3(sin(facing_yaw), 0, cos(facing_yaw)) * -1.0
	_dodge_dir = dir
	action = "dodge"
	_action_t = 0.0
	_action_len = 0.42
	invuln = maxf(invuln, 0.34)
	dodge_cd = 0.42 + (0.0 if Game.has_skill("cb2") else 0.2)
	Sfx.play("dodge")
	if mv.length() > 0.2:
		facing_yaw = atan2(-dir.x, -dir.z)
	model.state = "dodge"


func _try_attack(heavy: bool) -> void:
	if action != "" and not (action == "attack" and _action_t > _action_len * 0.6):
		return
	var w: Dictionary = Game.weapon_item()
	var cost := float(w["cost"]) * (2.0 if heavy else 1.0)
	if Game.stamina < cost:
		_atk_buf = 0.0
		if _warn_cd <= 0.0:
			Game.toast("Not enough stamina.", "warn")
			_warn_cd = 1.5
		return
	var style := String(w["style"])
	if style == "ranged":
		if not _consume_ammo():
			_atk_buf = 0.0
			return
	_atk_buf = 0.0
	Game.stamina -= cost
	_stamina_delay = 0.9
	_out_of_combat = 0.0
	_hit_set = {}
	var cd := float(w["cd"])
	action = "attack"
	_action_t = 0.0
	if style == "ranged":
		_atk_kind = "shoot"
		_action_len = maxf(cd, 0.5)
		_atk_dmg_mult = 1.0
	elif heavy:
		_atk_kind = "heavy"
		_action_len = cd * 2.2
		_atk_dmg_mult = 2.3
		Sfx.play("swing_heavy")
	elif style == "spear":
		_atk_kind = "thrust"
		_action_len = cd * 1.05
		_atk_dmg_mult = 1.0
		Sfx.play("swing", 0.9)
	else:
		_atk_chain = (_atk_chain % 3) + 1 if _atk_chain_t > 0.0 else 1
		_atk_kind = "swing%d" % _atk_chain
		_action_len = cd * (1.25 if _atk_chain == 3 else 1.0)
		_atk_dmg_mult = 1.35 if _atk_chain == 3 else 1.0
		Sfx.play("swing", 1.0 + 0.08 * _atk_chain)
	_fired = false
	model.action_kind = _atk_kind
	model.action_len = _action_len
	model.state = "attack"
	# face the aim direction / nearest enemy
	var tgt: Node = _nearest_enemy(float(w["reach"]) + 3.5)
	if tgt:
		var d: Vector3 = tgt.global_position - global_position
		facing_yaw = atan2(-d.x, -d.z)
	elif _move_input().length() < 0.2:
		facing_yaw = cam_yaw
	if style != "fist" and style != "ranged" and w.has("dur") and int(w.get("dur", 0)) > 0:
		_wear_weapon(1.0 if _atk_kind != "heavy" else 2.0)


var _fired: bool = false


func _consume_ammo() -> bool:
	if _ammo_charge <= 0:
		if Inv.count("crystal") <= 0:
			Game.toast("The cannon needs an Energy Crystal.", "warn")
			Sfx.play("invalid")
			return false
		Inv.remove("crystal", 1)
		_ammo_charge = 8
	_ammo_charge -= 1
	return true


func _wear_weapon(amount: float) -> void:
	if not Game.equip.has("weapon"):
		return
	var e: Dictionary = Game.equip["weapon"]
	if float(e.get("dur", 0.0)) <= 0.0:
		return
	e["dur"] = float(e["dur"]) - amount
	if float(e["dur"]) <= 0.0:
		Game.toast("Your %s broke!" % Data.item_name(e["id"]), "warn")
		Game.equip.erase("weapon")
		Game.equipment_changed.emit()
		Sfx.play("hit_metal")


func _nearest_enemy(r: float) -> Node:
	if world == null:
		return null
	var best: Node = null
	var bd := r
	for e in world.enemies_near(global_position, r):
		if not is_instance_valid(e) or not e.alive:
			continue
		var d: float = e.global_position.distance_to(global_position)
		var fwd := Vector3(-sin(facing_yaw), 0, -cos(facing_yaw))
		var cam_fwd := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
		var to: Vector3 = (e.global_position - global_position).normalized()
		if to.dot(cam_fwd) < 0.2 and to.dot(fwd) < 0.2:
			continue
		if d < bd:
			bd = d
			best = e
	return best


func _update_attack() -> void:
	var f := _action_t / maxf(_action_len, 0.01)
	var w: Dictionary = Game.weapon_item()
	var style := String(w["style"])
	if style == "ranged":
		if f >= 0.3 and not _fired:
			_fired = true
			_fire_projectile(w)
		return
	if f < 0.28 or f > 0.58:
		return
	var reach := float(w["reach"]) + (0.4 if _atk_kind == "heavy" else 0.0)
	var cone := 0.35 if style == "spear" else (-0.1 if _atk_kind == "heavy" else 0.25)
	var fwd := Vector3(-sin(facing_yaw), 0, -cos(facing_yaw))
	var origin := global_position + Vector3(0, 1.0, 0)
	var dmg_base := float(w["dmg"]) * _atk_dmg_mult * (1.15 if Game.has_skill("cb1") else 1.0)
	for e in world.hittables_near(global_position, reach + 1.8):
		if not is_instance_valid(e) or _hit_set.has(e.get_instance_id()):
			continue
		var tpos: Vector3 = e.hit_center()
		var to := tpos - origin
		var flat := Vector3(to.x, 0, to.z)
		var dist := flat.length() - float(e.hit_radius)
		if dist > reach:
			continue
		if flat.length() > 0.2 and fwd.dot(flat.normalized()) < cone:
			continue
		if _wall_between(origin, tpos):
			continue
		_hit_set[e.get_instance_id()] = true
		var crit := randf() < 0.1
		var dmg := dmg_base * (1.5 if crit else 1.0) * randf_range(0.92, 1.08)
		e.take_damage(dmg, global_position, 6.0 if _atk_kind != "heavy" else 11.0, self, crit)
		Sfx.play("hit_metal" if e.metallic else "hit", randf_range(0.92, 1.08))
		if bool(Game.settings["vibration"]):
			Input.vibrate_handheld(20)
		_shake = maxf(_shake, 0.12 if _atk_kind != "heavy" else 0.3)
	# break destructible world objects in front (none here) handled by resources via gather


func _wall_between(a: Vector3, b: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(a, b, 1 | 2)
	q.hit_from_inside = false
	var r := space.intersect_ray(q)
	if r.is_empty():
		return false
	# allow hits through structures that are not walls; terrain between = blocked
	return (r["position"] as Vector3).distance_to(b) > 1.1


func _fire_projectile(w: Dictionary) -> void:
	var origin := global_position + Vector3(0, 1.35, 0) + Vector3(-sin(facing_yaw), 0, -cos(facing_yaw)) * 0.6
	var dir := _aim_dir(origin)
	facing_yaw = atan2(-dir.x, -dir.z)
	var dmg := float(w["dmg"]) * (1.15 if Game.has_skill("cb1") else 1.0)
	world.spawn_projectile(origin, dir, dmg, true, 36.0, Color(0.45, 0.9, 1.0), self)
	Sfx.play("shot")
	_shake = 0.1


func _aim_dir(origin: Vector3) -> Vector3:
	var cam_fwd: Vector3 = -cam.global_transform.basis.z
	var target := origin + cam_fwd * 30.0
	var best: Node = null
	var bd := 0.93
	for e in world.enemies_near(global_position, 38.0):
		if not is_instance_valid(e) or not e.alive:
			continue
		var to: Vector3 = (e.hit_center() - origin).normalized()
		var d := cam_fwd.dot(to)
		if d > bd:
			bd = d
			best = e
	if best:
		target = best.hit_center()
	return (target - origin).normalized()


# ----------------------------------------------------------------- gather / interact
func _do_interact(_repeat: bool) -> void:
	if action != "" and action != "gather":
		return
	if prompt_target == null or not is_instance_valid(prompt_target):
		return
	if not prompt_target.can_interact(self):
		return
	prompt_target.interact(self)


## Called by resource nodes to start the gather animation; the node's apply_gather() fires mid-swing.
func begin_gather(node: Node, kind: String) -> void:
	_gather_target = node
	action = "gather"
	_action_t = 0.0
	_action_len = 0.62 if kind != "pluck" else 0.5
	_gather_did = false
	model.action_kind = kind
	model.action_len = _action_len
	model.state = "gather"
	var d: Vector3 = node.global_position - global_position
	facing_yaw = atan2(-d.x, -d.z)
	var held := ""
	match kind:
		"chop":
			var i := Inv.best_tool("axe")
			if i >= 0:
				held = String(Inv.slots[i]["id"])
		"mine":
			var j := Inv.best_tool("pick")
			if j >= 0:
				held = String(Inv.slots[j]["id"])
	model.set_held(held)


func _start_gather(node: Node) -> void:
	if node.has_method("start_gather"):
		node.start_gather(self)


func _update_gather() -> void:
	var f := _action_t / maxf(_action_len, 0.01)
	if f >= 0.5 and not _gather_did:
		_gather_did = true
		if _gather_target and is_instance_valid(_gather_target):
			_gather_target.apply_gather(self)


func begin_interact_anim() -> void:
	if action == "":
		action = "interact"
		_action_t = 0.0
		_action_len = 0.5
		model.action_len = 0.5
		model.state = "interact"


func _refresh_held_tool() -> void:
	pass


# ----------------------------------------------------------------- movement
func _movement(delta: float) -> void:
	grounded = is_on_floor()
	if grounded:
		_coyote = 0.12
		_air_time = 0.0
	else:
		_coyote = maxf(_coyote - delta, 0.0)
		_air_time += delta
	var mv := _move_input()
	var want := Vector3.ZERO
	if mv.length() > 0.05:
		want = Basis(Vector3.UP, cam_yaw) * Vector3(mv.x, 0, mv.y)
		want = want.limit_length(1.0)
	var speed := 0.0
	var mag := clampf(mv.length(), 0.0, 1.0)
	var sprinting := false
	if swimming:
		speed = SWIM_SPEED * mag
		if sprint_held and Game.stamina > 5.0:
			speed *= 1.35
			Game.stamina -= 6.0 * delta
			_stamina_delay = 0.6
	elif crouch_on:
		speed = CROUCH_SPEED * mag
	else:
		if mag > 0.62 or sprint_held:
			speed = RUN_SPEED
		else:
			speed = WALK_SPEED * (mag / 0.62)
		if sprint_held and mag > 0.3 and Game.stamina > 2.0:
			speed = SPRINT_SPEED
			sprinting = true
			Game.stamina = maxf(Game.stamina - SPRINT_COST * delta, 0.0)
			_stamina_delay = 0.8
		elif sprint_held and Game.stamina <= 2.0:
			sprint_held = false
			_sprint_from_touch = false
	if action == "attack":
		speed *= 0.35
	elif action == "gather" or action == "interact":
		speed = 0.0
	elif action == "hurt":
		speed *= 0.4
	var vel_xz := Vector3(velocity.x, 0, velocity.z)
	if action == "dodge":
		var f := _action_t / _action_len
		var sp := lerpf(10.5, 4.0, f)
		vel_xz = _dodge_dir * sp
	else:
		var target := want * speed
		var accel := 42.0 if grounded or swimming else 11.0
		if want == Vector3.ZERO:
			accel = 52.0 if grounded else 4.0
		vel_xz = vel_xz.move_toward(target, accel * delta)
		if want.length() > 0.1 and action != "attack":
			var target_yaw := atan2(-want.x, -want.z)
			facing_yaw = lerp_angle(facing_yaw, target_yaw, clampf(delta * 12.0, 0.0, 1.0))
	velocity.x = vel_xz.x
	velocity.z = vel_xz.z
	if swimming:
		# buoyancy towards the surface
		var surf := -0.15
		velocity.y = lerpf(velocity.y, clampf((surf - global_position.y) * 4.0, -3.0, 3.0), delta * 6.0)
		if _jump_buf > 0.0:
			velocity.y = 4.0
			_jump_buf = 0.0
	else:
		if not grounded:
			velocity.y -= GRAVITY * delta
			velocity.y = maxf(velocity.y, -40.0)
		if _jump_buf > 0.0 and (grounded or _coyote > 0.0) and action != "gather" and action != "dodge":
			if Game.stamina >= JUMP_COST * 0.5:
				velocity.y = JUMP_VELOCITY
				_jump_buf = 0.0
				_coyote = 0.0
				Game.stamina = maxf(Game.stamina - JUMP_COST, 0.0)
				_stamina_delay = 0.7
				Sfx.play("jump")
				floor_snap_length = 0.0
				grounded = false
				_fall_peak_y = global_position.y
		elif grounded:
			floor_snap_length = 0.55
			if velocity.y < 0.0:
				velocity.y = -2.0
	if not grounded:
		floor_snap_length = 0.0 if velocity.y > 0.0 else 0.55
	speed_xz = Vector3(velocity.x, 0, velocity.z).length()
	if sprinting:
		model.speed01 = 1.0
	else:
		model.speed01 = clampf(speed_xz / SPRINT_SPEED * 1.45, 0.0, 1.0) if speed_xz > 0.2 else 0.0


func _step_up() -> void:
	if not is_on_floor() or swimming or action == "dodge":
		return
	var hv := Vector3(velocity.x, 0, velocity.z)
	if hv.length() < 0.6:
		return
	var motion := hv.normalized() * 0.5
	if not test_move(global_transform, motion):
		return
	var up := Vector3(0, 0.7, 0)
	if test_move(global_transform, up):
		return
	var raised := global_transform.translated(up)
	if test_move(raised, motion):
		return
	global_position += up * 0.9 + motion * 0.5


func _post_move(delta: float) -> void:
	var p := global_position
	# fall tracking / landing
	if is_on_floor():
		if _air_time > 0.15 or _fall_peak_y - p.y > 1.0:
			var drop := _fall_peak_y - p.y
			if drop > 2.0 and not swimming:
				Sfx.play("land")
				_land_t = 0.25
				_spawn_dust()
			if drop > 8.0 and not swimming and invuln <= 0.0:
				hurt((drop - 8.0) * 6.0, Vector3.ZERO, 0.0, true)
		_fall_peak_y = p.y
	else:
		_fall_peak_y = maxf(_fall_peak_y, p.y)
		if swimming:
			_fall_peak_y = p.y
	# safety net: never end up under the terrain or outside the world
	var gh := WG.height_at(p.x, p.z)
	if p.y < gh - 3.0 and gh > -2.0:
		global_position.y = gh + 1.2
		velocity = Vector3.ZERO
	var lim := DW.WORLD_SIZE * 0.5 - 4.0
	if absf(p.x) > lim or absf(p.z) > lim:
		global_position.x = clampf(p.x, -lim, lim)
		global_position.z = clampf(p.z, -lim, lim)
	# stuck detection: pushing hard but not moving for a while
	if _move_input().length() > 0.6 and speed_xz < 0.4 and action == "" and is_on_floor():
		_stuck_t += delta
		if _stuck_t > 3.0:
			global_position += Vector3(0, 0.6, 0) + Vector3(sin(cam_yaw + PI), 0, cos(cam_yaw + PI)) * 0.5
			_stuck_t = 0.0
	else:
		_stuck_t = 0.0
	# footsteps
	if is_on_floor() and speed_xz > 1.2 and not swimming:
		_step_t -= delta * (speed_xz / 5.0 + 0.4)
		if _step_t <= 0.0:
			_step_t = 0.42
			Sfx.play(_surface_sound(), randf_range(0.9, 1.1), -6.0 if crouch_on else 0.0)
	elif swimming and speed_xz > 0.8:
		_step_t -= delta
		if _step_t <= 0.0:
			_step_t = 0.6
			Sfx.play("step_water", 1.0, -4.0)


func _surface_sound() -> String:
	var p := global_position
	var h := WG.height_at(p.x, p.z)
	if h < 0.9:
		return "step_water"
	if world and world.is_on_metal(p):
		return "step_metal"
	match current_region:
		"coast":
			return "step_sand" if h < 2.9 else "step_grass"
		"forest":
			return "step_grass"
		"highlands", "ashen":
			return "step_stone"
		"core":
			return "step_metal"
	return "step_grass"


func _spawn_dust() -> void:
	if world and world.has_method("spawn_burst"):
		world.spawn_burst(global_position + Vector3(0, 0.1, 0), Color(0.75, 0.7, 0.6), 8, 2.0)


# ----------------------------------------------------------------- survival
func _survival(delta: float) -> void:
	var g := Game
	var busy := action == "dodge" or sprint_held and speed_xz > 5.0
	_stamina_delay = maxf(_stamina_delay - delta, 0.0)
	if _stamina_delay <= 0.0 and not busy:
		var rate := 17.0 * (1.3 if g.has_skill("sv3") else 1.0)
		if g.hunger < 25.0:
			rate *= 0.6
		if swimming:
			rate *= 0.4
		g.stamina = minf(g.stamina + rate * delta, 100.0)
	# hunger
	var drain := 0.1 * (0.75 if g.has_skill("sv2") else 1.0)
	if speed_xz > 5.0:
		drain *= 1.6
	g.hunger = maxf(g.hunger - drain * delta, 0.0)
	# temperature
	var offset: float = world.temperature_offset(global_position) if world else 0.0
	if offset > 0.0:
		offset *= (1.0 - g.heat_protection())
	else:
		offset *= (1.0 - g.cold_protection())
	var target := 50.0 + offset
	g.temperature = lerpf(g.temperature, target, clampf(delta * 0.12, 0.0, 1.0))
	if g.heat_ward > 0.0:
		g.heat_ward = maxf(g.heat_ward - delta, 0.0)
	var dmg_rate := 0.0
	if g.temperature > 80.0:
		dmg_rate = (g.temperature - 80.0) * 0.22
		if _warn_cd <= 0.0:
			Game.toast("You are overheating! Find shade, use a Heat Ward Tonic or wear an Environmental Suit.", "warn")
			_warn_cd = 6.0
	elif g.temperature < 20.0:
		dmg_rate = (20.0 - g.temperature) * 0.2
		if _warn_cd <= 0.0:
			Game.toast("You are freezing! Stand near a campfire or shelter.", "warn")
			_warn_cd = 6.0
	if dmg_rate > 0.0 and invuln <= 0.0:
		g.health = maxf(g.health - dmg_rate * delta, 0.0)
		if g.health <= 0.0:
			die("exposure")
			return
	# starvation hurts slowly but never kills outright
	if g.hunger <= 0.0 and g.health > 10.0:
		g.health -= 0.7 * delta
	# regeneration
	if g.hunger > 40.0 and _out_of_combat > 6.0 and dmg_rate <= 0.0 and g.health < g.max_health:
		g.health = minf(g.health + 0.9 * delta, g.max_health)
	if g.hunger < 20.0 and _warn_cd <= 0.0 and g.hunger > 0.0:
		Game.toast("You are hungry. Eat something.", "warn")
		_warn_cd = 12.0
	g.stats_changed.emit()


func hurt(amount: float, from_pos: Vector3, knock: float, ignore_armor: bool = false) -> void:
	if dead or invuln > 0.0 or amount <= 0.0:
		return
	if world and world.has_method("is_cutscene") and world.is_cutscene():
		return
	var dmg := amount * (1.0 if ignore_armor else (1.0 - Game.damage_reduction()))
	Game.health = maxf(Game.health - dmg, 0.0)
	_out_of_combat = 0.0
	invuln = 0.45
	_shake = 0.3
	Sfx.play("hurt")
	if bool(Game.settings["vibration"]):
		Input.vibrate_handheld(60)
	if world:
		world.spawn_burst(global_position + Vector3(0, 1.1, 0), Color(0.9, 0.15, 0.15), 8, 3.0)
		world.hit_flash()
	if knock > 0.0 and from_pos != Vector3.ZERO:
		var away := (global_position - from_pos)
		away.y = 0
		away = away.normalized()
		velocity.x = away.x * knock
		velocity.z = away.z * knock
	if action == "attack" or action == "gather":
		pass
	elif action == "":
		action = "hurt"
		_action_t = 0.0
		_action_len = 0.3
		model.state = "hurt"
	if Game.health <= 0.0:
		die("combat")


func die(_cause: String) -> void:
	if dead:
		return
	dead = true
	action = ""
	Sfx.play("death")
	Game.stats_changed.emit()
	model.phase_t = 0.0
	died.emit()


func revive() -> void:
	dead = false
	invuln = 3.0
	action = ""
	model.state = "idle"
	model.phase_t = 0.0
	swimming = false
	velocity = Vector3.ZERO


# ----------------------------------------------------------------- interaction scan
func _scan_interactables(delta: float) -> void:
	_scan_t -= delta
	if _scan_t > 0.0:
		return
	_scan_t = 0.1
	var best: Node = null
	var best_score := 1e9
	var fwd := Vector3(-sin(facing_yaw), 0, -cos(facing_yaw))
	for n in world.interactables_near(global_position, 4.0):
		if not is_instance_valid(n) or not n.can_interact(self):
			continue
		var to: Vector3 = n.global_position - global_position
		var d := Vector2(to.x, to.z).length()
		if d > n.interact_radius:
			continue
		var facing := fwd.dot(Vector3(to.x, 0, to.z).normalized()) if d > 0.1 else 1.0
		var score := d - facing * 1.0
		if score < best_score:
			best_score = score
			best = n
	prompt_target = best
	prompt_text = best.get_prompt(self) if best != null else ""


# ----------------------------------------------------------------- visuals
func _update_model(delta: float) -> void:
	model.rotation.y = facing_yaw
	model.crouch = crouch_on
	if action == "":
		if swimming:
			model.state = "swim"
		elif not grounded and _air_time > 0.12:
			model.state = "jump" if velocity.y > 0.5 else "fall"
		elif _land_t > 0.0:
			model.state = "land"
		else:
			model.state = "move" if model.speed01 > 0.05 else "idle"
		model.phase_t = 0.0
	elif action == "hurt":
		model.state = "hurt"
	model.animate(delta)
	# hide the model if the camera is crammed against it
	var cd := cam.global_position.distance_to(global_position + Vector3(0, 1.4, 0))
	model.visible = cd > 0.9


func _update_camera(delta: float) -> void:
	var focus := global_position + Vector3(0, 1.55 if not crouch_on else 1.2, 0)
	cam_rig.global_position = cam_rig.global_position.lerp(focus, clampf(delta * 16.0, 0.0, 1.0))
	if (cam_rig.global_position - focus).length() > 6.0:
		cam_rig.global_position = focus
	cam_rig.rotation = Vector3(cam_pitch, cam_yaw, 0)
	var boss_zoom := 1.0
	if world and world.has_method("boss_zoom"):
		boss_zoom = world.boss_zoom()
	var want := cam_dist * boss_zoom
	_cam_dist_now = lerpf(_cam_dist_now, want, clampf(delta * 3.0, 0.0, 1.0))
	arm.spring_length = _cam_dist_now
	_shake = maxf(_shake - delta * 1.8, 0.0)
	if _shake > 0.0:
		cam.h_offset = randf_range(-1.0, 1.0) * _shake * 0.18
		cam.v_offset = randf_range(-1.0, 1.0) * _shake * 0.18
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0
	# slight FOV widening while sprinting
	var tf := 68.0 + (6.0 if speed_xz > 6.5 else 0.0)
	cam.fov = lerpf(cam.fov, tf, clampf(delta * 4.0, 0.0, 1.0))


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)
