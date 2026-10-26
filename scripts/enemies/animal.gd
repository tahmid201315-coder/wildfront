extends CharacterBody3D
## Passive wildlife: wanders, flees from the player, can be hunted for meat and hide.

const WG = preload("res://scripts/world/world_gen.gd")
const EnemyModels = preload("res://scripts/gfx/enemy_models.gd")

signal died(a)

var aid: String = ""
var def: Dictionary = {}
var alive: bool = true
var hp: float = 20.0
var home: Vector3 = Vector3.ZERO
var hit_radius: float = 0.6
var metallic: bool = false
var model: Node3D
var pivots: Dictionary = {}
var _facing: float = 0.0
var _wander_t: float = 0.0
var _dir: Vector3 = Vector3.ZERO
var _flee_t: float = 0.0
var _phase: float = 0.0
var _flash: float = 0.0
var _dead_t: float = 0.0
var den: Dictionary = {}


func setup(id: String, d: Dictionary, pos: Vector3) -> void:
	aid = id
	def = d
	hp = float(d["hp"])
	hit_radius = 0.5 + float(d["size"]) * 0.3
	collision_layer = 8
	collision_mask = 1 | 2
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35 * float(d["size"])
	cap.height = 1.0 * float(d["size"]) + 0.4
	cs.shape = cap
	cs.position.y = cap.height * 0.5
	add_child(cs)
	model = EnemyModels.build(id)
	add_child(model)
	for c in model.get_children():
		pivots[c.name] = c
	home = pos
	global_position = pos
	_facing = randf() * TAU
	floor_snap_length = 0.6


func hit_center() -> Vector3:
	return global_position + Vector3(0, 0.6, 0)


func take_damage(dmg: float, from_pos: Vector3, knock: float, src: Node, _crit: bool) -> void:
	if not alive:
		return
	hp -= dmg
	_flee_t = 5.0
	_flash = 0.15
	if Game.world:
		Game.world.spawn_burst(hit_center(), Color(0.9, 0.3, 0.25), 6, 3.0)
		Game.world.show_damage(hit_center() + Vector3(0, 0.5, 0), dmg, false)
	if knock > 0.0 and from_pos != Vector3.ZERO:
		var away := global_position - from_pos
		away.y = 0
		velocity += away.normalized() * knock * 0.5
	if hp <= 0.0:
		alive = false
		collision_layer = 0
		if Game.world:
			Game.world.animals.erase(self)
		for d in def["drops"]:
			var n := randi_range(int(d[1]), int(d[2]))
			if n > 0:
				Game.give_item(String(d[0]), n)
				Game.toast("+%d %s" % [n, Data.item_name(String(d[0]))], "item")
		Game.add_stat("hunt:" + aid)
		Game.add_stat("hunted")
		Game.add_xp(int(def["xp"]))
		Sfx.play_at("enemy_die", global_position, 1.4, 40.0)
		died.emit(self)


func _physics_process(delta: float) -> void:
	if not alive:
		_dead_t += delta
		model.rotation.z = minf(_dead_t * 4.0, 1.0) * PI * 0.5
		model.scale = Vector3.ONE * clampf(1.0 - (_dead_t - 1.0), 0.0, 1.0)
		if _dead_t > 2.0:
			queue_free()
		return
	if not Game.is_playing():
		return
	var pl: Node3D = Game.world.player if Game.world else null
	var dist := 999.0
	if pl:
		dist = Vector2(pl.global_position.x - global_position.x, pl.global_position.z - global_position.z).length()
	var want := Vector3.ZERO
	var spd := float(def["speed"])
	if dist < float(def["flee"]) * (0.5 if pl and pl.crouch_on else 1.0) or _flee_t > 0.0:
		_flee_t = maxf(_flee_t - delta, 0.0)
		var away := global_position - pl.global_position
		away.y = 0
		want = away.normalized() * spd
		if aid == "crab" and dist < 3.0:
			want = away.normalized().rotated(Vector3.UP, 1.2) * spd
	else:
		_wander_t -= delta
		if _wander_t <= 0.0:
			_wander_t = randf_range(2.5, 6.0)
			var a := randf() * TAU
			_dir = Vector3.ZERO if randf() < 0.45 else Vector3(cos(a), 0, sin(a))
			var th := home - global_position
			th.y = 0
			if th.length() > 14.0:
				_dir = th.normalized()
		want = _dir * spd * 0.25
	var hv := Vector3(velocity.x, 0, velocity.z).move_toward(want, 25.0 * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	else:
		velocity.y = -1.0
	if hv.length() > 0.2:
		_facing = lerp_angle(_facing, atan2(-hv.x, -hv.z), clampf(delta * 8.0, 0.0, 1.0))
	rotation.y = _facing
	move_and_slide()
	var h := WG.height_at(global_position.x, global_position.z)
	if h < 0.25 and aid != "crab":
		velocity.x = 0.0
		velocity.z = 0.0
		global_position = global_position.lerp(home, 0.1)
	_phase += delta * (3.0 + hv.length() * 1.5)
	var sw := sin(_phase) * clampf(hv.length() / 2.0, 0.0, 1.0) * 0.7
	for i in 4:
		if pivots.has("leg%d" % i):
			pivots["leg%d" % i].rotation.x = sw * (1.0 if (i == 0 or i == 3) else -1.0)
	if pivots.has("body") and aid == "crab":
		pivots["body"].rotation.z = sin(_phase * 2.0) * 0.08 * clampf(hv.length(), 0.0, 1.0)
