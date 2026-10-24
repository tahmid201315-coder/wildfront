extends CharacterBody3D
## Third-person player: movement, camera rig, survival tick, interaction targeting and abilities.

const PlayerModel = preload("res://scripts/player/player_model.gd")

const WALK_SPEED := 4.2
const RUN_SPEED := 7.2
const ACCEL := 26.0
const DECEL := 34.0
const JUMP_V := 7.4
const GRAVITY := 22.0
const SPRINT_COST := 13.0
const STAMINA_REGEN := 20.0

var world: Node = null
var touch: Node = null          # TouchControls, assigned by the HUD

var model: Node3D
var cam_rig: Node3D
var cam_pitch_node: Node3D
var spring: SpringArm3D
var camera: Camera3D
var glow_light: OmniLight3D

var cam_yaw: float = 0.0
var cam_yaw_target: float = 0.0
var cam_pitch: float = 0.35
var cam_pitch_target: float = 0.35
var cam_dist: float = 5.5
var cam_dist_target: float = 5.5
var facing_yaw: float = 0.0
var speed_xz: float = 0.0

var jump_buffer: float = 0.0
var jump_held: bool = false
var _coyote: float = 0.0
var _was_on_floor: bool = true
var _last_fall_speed: float = 0.0
var _exhausted: bool = false
var in_water: bool = false

var _busy_t: float = 0.0
var _anim_t: float = 0.0
var _anim_hold: String = ""
var _gather_node: Node = null
var _land_t: float = 0.0
var invuln: float = 0.0
var shield_t: float = 0.0
var glow_on: bool = false
var ability_cd: float = 0.0
var ability_cd_max: float = 1.0
var strike_cd: float = 0.0
var since_damage: float = 99.0

var current_target: Node = null
var prompt: String = ""
var _scan_t: float = 0.0
var _step_dist: float = 0.0
var _walk_acc: float = 0.0
var _look_acc: float = 0.0
var _stats_t: float = 0.0
var _shake_t: float = 0.0
var _shake_amp: float = 0.0
var _starve_msg_t: float = 0.0
var _temp_msg_t: float = 0.0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 3
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(52.0)
	floor_stop_on_slope = true
	floor_constant_speed = true
	safe_margin = 0.03
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = 0.85
	add_child(cs)
	model = PlayerModel.new()
	add_child(model)
	# camera rig is top_level so body rotation never twists the view
	cam_rig = Node3D.new()
	cam_rig.top_level = true
	add_child(cam_rig)
	cam_pitch_node = Node3D.new()
	cam_rig.add_child(cam_pitch_node)
	spring = SpringArm3D.new()
	spring.collision_mask = 3
	spring.margin = 0.35
	var ss := SphereShape3D.new()
	ss.radius = 0.25
	spring.shape = ss
	spring.spring_length = cam_dist
	cam_pitch_node.add_child(spring)
	spring.add_excluded_object(get_rid())
	camera = Camera3D.new()
	camera.near = 0.15
	camera.far = 220.0
	camera.fov = 68.0
	camera.current = true
	spring.add_child(camera)
	glow_light = OmniLight3D.new()
	glow_light.omni_range = 14.0
	glow_light.light_energy = 1.7
	glow_light.light_color = Color(1.0, 0.92, 0.65)
	glow_light.position = Vector3(0, 1.8, 0)
	glow_light.visible = false
	add_child(glow_light)
	cam_rig.global_position = global_position + Vector3(0, 1.55, 0)


func is_alive() -> bool:
	return Game.health > 0.0


func place_at(p: Vector3) -> void:
	global_position = p
	velocity = Vector3.ZERO
	cam_rig.global_position = p + Vector3(0, 1.55, 0)


# ------------------------------------------------------------ input from HUD
func apply_look(rel: Vector2) -> void:
	if not Game.is_playing():
		return
	var sens: float = 0.0055 * float(Game.settings["cam_sens"])
	var inv: float = -1.0 if bool(Game.settings["cam_invert"]) else 1.0
	cam_yaw_target -= rel.x * sens
	cam_pitch_target = clampf(cam_pitch_target + rel.y * sens * inv, -0.15, 1.25)
	_look_acc += absf(rel.x * sens)
	if _look_acc > 0.25:
		Quests.notify_event("look", "", _look_acc)
		_look_acc = 0.0


func apply_zoom(amount: float) -> void:
	cam_dist_target = clampf(cam_dist_target + amount, 3.2, 9.0)


func request_jump() -> void:
	jump_buffer = 0.14
	jump_held = true


func release_jump() -> void:
	jump_held = false


func cam_forward() -> Vector3:
	return -camera.global_transform.basis.z


func shake(amount: float) -> void:
	_shake_amp = maxf(_shake_amp, amount)
	_shake_t = 0.3


# ------------------------------------------------------------ frame update (camera + prompts)
func _process(delta: float) -> void:
	var k := 1.0 - exp(-16.0 * delta)
	cam_yaw = lerp_angle(cam_yaw, cam_yaw_target, k)
	cam_pitch = lerpf(cam_pitch, cam_pitch_target, k)
	cam_dist = lerpf(cam_dist, cam_dist_target, 1.0 - exp(-8.0 * delta))
	var target := global_position + Vector3(0, 1.55, 0)
	if cam_rig.global_position.distance_to(target) > 6.0:
		cam_rig.global_position = target
	else:
		cam_rig.global_position = cam_rig.global_position.lerp(target, 1.0 - exp(-18.0 * delta))
	cam_rig.rotation.y = cam_yaw
	cam_pitch_node.rotation.x = -cam_pitch
	spring.spring_length = cam_dist
	if _shake_t > 0.0:
		_shake_t -= delta
		camera.h_offset = randf_range(-1.0, 1.0) * _shake_amp * (_shake_t / 0.3)
		camera.v_offset = randf_range(-1.0, 1.0) * _shake_amp * (_shake_t / 0.3)
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
		_shake_amp = 0.0
	if _anim_t > 0.0:
		_anim_t -= delta
		if _anim_t <= 0.0 and _busy_t <= 0.0:
			_anim_hold = ""
	# model animation
	var state := _pick_anim()
	model.set_anim(state)
	model.update_anim(delta, speed_xz)
	# interaction scanning (throttled)
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = 0.12
		_scan_interactables()
	if glow_on != glow_light.visible:
		glow_light.visible = glow_on


func _pick_anim() -> String:
	if _anim_hold != "":
		return _anim_hold
	if not is_on_floor():
		return "jump" if velocity.y > 0.5 else "fall"
	if _land_t > 0.0:
		return "land"
	if speed_xz < 0.4:
		return "idle"
	return "run" if speed_xz > 5.6 else "walk"


func _scan_interactables() -> void:
	var best: Node = null
	var best_d := 9999.0
	var pos := global_position
	for n in get_tree().get_nodes_in_group("interactable"):
		if not is_instance_valid(n) or not n.visible:
			continue
		var d: float = pos.distance_to(n.global_position)
		var r: float = n.interact_radius
		if d <= r and d < best_d and n.can_interact(self):
			best = n
			best_d = d
	current_target = best
	prompt = best.get_prompt() if best != null else ""


# ------------------------------------------------------------ physics / movement
func _physics_process(delta: float) -> void:
	if not Game.is_playing() or not is_alive():
		velocity.x = 0.0
		velocity.z = 0.0
		speed_xz = 0.0
		return
	invuln = maxf(invuln - delta, 0.0)
	shield_t = maxf(shield_t - delta, 0.0)
	ability_cd = maxf(ability_cd - delta, 0.0)
	strike_cd = maxf(strike_cd - delta, 0.0)
	since_damage += delta
	_land_t = maxf(_land_t - delta, 0.0)
	jump_buffer = maxf(jump_buffer - delta, 0.0)

	# timed action lock (gathering / interacting)
	if _busy_t > 0.0:
		_busy_t -= delta
		if _busy_t <= 0.0:
			_anim_hold = ""
			if _gather_node != null and is_instance_valid(_gather_node):
				_gather_node.apply_gather(self)
			_gather_node = null

	var mv := Vector2.ZERO
	if touch != null:
		mv = touch.move_vec
	var kb := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if kb.length() > mv.length():
		mv = kb
	if _busy_t > 0.0:
		mv = Vector2.ZERO
	var mag := minf(mv.length(), 1.0)
	var moving := mag > 0.01
	var forward := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
	var right := Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
	var dir := (right * mv.x + forward * -mv.y)
	if dir.length() > 1.0:
		dir = dir.normalized()

	# water
	var ground_h: float = world.height_at(global_position.x, global_position.z) if world else 0.0
	in_water = world != null and ground_h < world.WATER_Y - 0.15
	var comp: Dictionary = Game.active_creature()
	var comp_sp: String = comp.get("species", "")

	# speed
	var wants_run := (mag > 0.82 or Input.is_action_pressed("run")) and moving
	if _exhausted and Game.stamina > 22.0:
		_exhausted = false
	var running := wants_run and Game.stamina > 1.0 and not _exhausted
	var want := 0.0
	if moving:
		want = RUN_SPEED if running else WALK_SPEED * clampf(mag / 0.82, 0.35, 1.0)
	if in_water and comp_sp != "pondling":
		want *= 0.6
	if Game.comfort < 25.0:
		want *= 0.9
	var hv := Vector2(velocity.x, velocity.z)
	var tv := Vector2(dir.x, dir.z).normalized() * want if moving else Vector2.ZERO
	hv = hv.move_toward(tv, (ACCEL if moving else DECEL) * delta)
	velocity.x = hv.x
	velocity.z = hv.y

	# stamina
	if running:
		Game.stamina = maxf(Game.stamina - SPRINT_COST * delta, 0.0)
		if Game.stamina <= 0.0:
			_exhausted = true
	elif is_on_floor():
		var regen := STAMINA_REGEN * (0.5 if Game.hunger < 15.0 else 1.0)
		if in_water and comp_sp == "pondling":
			regen *= 1.4
		Game.stamina = minf(Game.stamina + regen * delta, 100.0)

	# vertical
	if is_on_floor():
		_coyote = 0.12
		if not _was_on_floor and _last_fall_speed < -5.0:
			_land_t = 0.22
			Sfx.play("land", 1.0, -6.0)
	else:
		_coyote = maxf(_coyote - delta, 0.0)
		velocity.y -= GRAVITY * delta
		_last_fall_speed = velocity.y
	if jump_buffer > 0.0 and _coyote > 0.0 and Game.stamina >= 6.0 and _busy_t <= 0.0:
		velocity.y = JUMP_V
		Game.stamina -= 6.0
		jump_buffer = 0.0
		_coyote = 0.0
		Sfx.play("jump", 1.0, -6.0)
	# Glimmerwing passive: hold jump while falling to glide
	if comp_sp == "glimmerwing" and jump_held and velocity.y < -1.0 and not is_on_floor() and Game.stamina > 3.0:
		velocity.y = maxf(velocity.y, -2.2)
		Game.stamina = maxf(Game.stamina - 9.0 * delta, 0.0)
	_was_on_floor = is_on_floor()

	var before := global_position
	move_and_slide()
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	speed_xz = moved / maxf(delta, 0.0001)
	if speed_xz > 14.0 and is_on_floor():
		speed_xz = Vector2(velocity.x, velocity.z).length()
	if speed_xz > 0.3:
		var yaw := atan2(-velocity.x, -velocity.z) if Vector2(velocity.x, velocity.z).length() > 0.3 else facing_yaw
		facing_yaw = lerp_angle(facing_yaw, yaw, 1.0 - exp(-14.0 * delta))
	model.rotation.y = facing_yaw

	# quests: distance walked; footsteps
	if is_on_floor():
		_walk_acc += moved
		if _walk_acc >= 1.0:
			Quests.notify_event("walk", "", _walk_acc)
			_walk_acc = 0.0
		_step_dist += moved
		if _step_dist > (3.0 if running else 2.2) and speed_xz > 1.0:
			_step_dist = 0.0
			Sfx.play("step", randf_range(0.85, 1.15), -12.0)

	# world safety nets
	var half: float = Data.WORLD_HALF - 6.0
	if absf(global_position.x) > half or absf(global_position.z) > half:
		global_position.x = clampf(global_position.x, -half, half)
		global_position.z = clampf(global_position.z, -half, half)
	if world != null:
		var gh: float = world.height_at(global_position.x, global_position.z)
		if global_position.y < gh - 4.0:
			place_at(Vector3(global_position.x, gh + 1.0, global_position.z))
			Game.toast("You were pulled back onto solid ground.", "info")

	_survival_tick(delta)


# ------------------------------------------------------------ survival
func _survival_tick(delta: float) -> void:
	var G := Game
	G.play_seconds += delta
	G.hunger = maxf(G.hunger - (0.11 + (0.05 if speed_xz > 5.6 else 0.0)) * delta, 0.0)
	if G.hunger <= 0.0:
		if G.health > 1.0:
			G.health = maxf(G.health - 0.5 * delta, 1.0)
		_starve_msg_t -= delta
		if _starve_msg_t <= 0.0:
			_starve_msg_t = 20.0
			G.toast("You are starving! Eat something from your Pack.", "warn")
	elif G.hunger > 55.0 and since_damage > 8.0 and G.health < G.max_health:
		G.health = minf(G.health + 0.8 * delta, G.max_health)
	# temperature comfort
	if world != null:
		var info: Dictionary = world.comfort_info(global_position)
		var target: float = info["target"]
		if info["kind"] == "hot":
			var comp_sp: String = Game.active_creature().get("species", "")
			if G.heat_resist > 0.0 or comp_sp == "cinderstag":
				target = maxf(target, 62.0)
		G.heat_resist = maxf(G.heat_resist - delta, 0.0)
		G.comfort = move_toward(G.comfort, target, 5.0 * delta)
		G.set_meta("comfort_kind", info["kind"])
		if G.comfort < 25.0:
			if G.health > 1.0:
				G.health = maxf(G.health - 0.7 * delta, 1.0)
			_temp_msg_t -= delta
			if _temp_msg_t <= 0.0:
				_temp_msg_t = 25.0
				G.toast("You are too %s! %s" % ["hot" if info["kind"] == "hot" else "cold",
					"Drink a Cooling Tonic or leave the area." if info["kind"] == "hot" else "Stand by a campfire or wait for daylight."], "warn")
	_stats_t -= delta
	if _stats_t <= 0.0:
		_stats_t = 0.15
		G.stats_changed.emit()


func hurt(amount: float, _src: Node = null) -> void:
	if invuln > 0.0 or not is_alive():
		return
	var a := amount * (0.5 if shield_t > 0.0 else 1.0)
	Game.damage_player(a)
	invuln = 0.8
	since_damage = 0.0
	Sfx.play("hurt")
	shake(0.12)
	if bool(Game.settings["vibration"]):
		Input.vibrate_handheld(80)
	if world != null:
		world.float_text(global_position + Vector3(0, 2.2, 0), "-%d" % int(a), Color(1, 0.35, 0.3))
	if Game.health <= 0.0:
		_anim_hold = ""
		world.on_player_defeated()


# ------------------------------------------------------------ actions
func do_primary() -> void:
	if not Game.is_playing() or _busy_t > 0.0 or not is_alive():
		return
	if current_target != null and is_instance_valid(current_target) and current_target.can_interact(self):
		current_target.interact(self)


func begin_gather(node: Node) -> void:
	_gather_node = node
	_busy_t = 0.55
	_anim_hold = "gather"
	var to: Vector3 = node.global_position - global_position
	facing_yaw = atan2(-to.x, -to.z)
	if bool(Game.settings["vibration"]):
		Input.vibrate_handheld(25)


func begin_interact() -> void:
	_busy_t = 0.45
	_anim_hold = "interact"
	_gather_node = null


func celebrate() -> void:
	_busy_t = 1.3
	_anim_hold = "celebrate"
	_gather_node = null


func rest_for(seconds: float) -> void:
	_busy_t = seconds
	_anim_hold = "rest"
	_gather_node = null


func do_strike() -> void:
	if not Game.is_playing() or strike_cd > 0.0 or _busy_t > 0.0 or not is_alive():
		return
	strike_cd = 0.55
	_anim_hold = "gather"
	_anim_t = 0.3  # animation only; movement stays free so the player can dodge
	var fwd := Vector3(-sin(facing_yaw), 0, -cos(facing_yaw))
	var hit := false
	for h in get_tree().get_nodes_in_group("hostile"):
		var to: Vector3 = h.global_position - global_position
		to.y = 0.0
		var reach := 3.6 + 1.2 * float(h.def.get("scale", 1.0))
		if to.length() < reach and to.normalized().dot(fwd) > 0.1:
			var dmg := 8.0 + Game.level * 1.5 + (4.0 if Inv.count("stone_axe") > 0 else 0.0)
			h.take_damage(dmg, "player")
			hit = true
			break
	Sfx.play("hit" if hit else "jump", 1.0 if hit else 1.6, -3.0)
	if hit and bool(Game.settings["vibration"]):
		Input.vibrate_handheld(30)


func ability_name() -> String:
	var c := Game.active_creature()
	if c.is_empty():
		return ""
	return str(Data.creatures[c["species"]]["ability_name"])


func use_ability() -> void:
	if not Game.is_playing() or not is_alive():
		return
	var c := Game.active_creature()
	if c.is_empty():
		Game.toast("You need an active companion. Befriend a Wildling first.", "info")
		return
	var def: Dictionary = Data.creatures[c["species"]]
	if ability_cd > 0.0:
		Game.toast("%s needs %d s to recover." % [def["ability_name"], ceili(ability_cd)], "info")
		return
	var ok := true
	match def["ability"]:
		"sniff":
			var n: int = world.reveal_resources(global_position, 40.0, 12.0)
			Game.toast("Mossbun sniffs out %d nearby resources." % n, "info")
		"shield":
			shield_t = 8.0
			Game.toast("Thorn Guard! You take half damage for 8 s.", "info")
		"updraft":
			if Game.stamina < 20.0:
				Game.toast("Too tired for an Updraft.", "warn")
				ok = false
			else:
				Game.stamina -= 20.0
				velocity.y = 11.0
				_coyote = 0.0
		"glow":
			glow_on = not glow_on
			Game.toast("Lantern Tail %s." % ("shines" if glow_on else "dims"), "info")
		"mist":
			Game.heal_player(25.0)
			world.spawn_burst(global_position + Vector3(0, 1.0, 0), Color(0.5, 0.8, 1.0), 14)
		"dig":
			world.dig_for_treasure(global_position)
		"tend":
			var n2: int = world.tend_plots(global_position, 14.0)
			Game.toast("Snailbell tended %d plot(s)." % n2 if n2 > 0 else "No plots nearby to tend.", "info")
			if n2 == 0:
				ok = false
		"scout":
			Game.reveal_area(global_position.x, global_position.z, 40.0)
			Game.toast("Thistlefinch scouts ahead. The map is revealed nearby.", "info")
	if ok:
		ability_cd_max = float(def["cd"])
		ability_cd = ability_cd_max
		Sfx.play("ability")
		Sfx.play_voice(c["species"])
		Quests.notify_event("ability", c["species"], 1)
		Game.creature_add_xp(c["uid"], 3)
