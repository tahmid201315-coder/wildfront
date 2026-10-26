extends "res://scripts/world/interactable.gd"
## A placed structure. Behaviour depends on `sid` (campfire, chest, door, processor, turret ...).

const StructModels = preload("res://scripts/gfx/struct_models.gd")

var sid: String = ""
var kind: String = "free"
var yaw: float = 0.0
var cell: Vector2i = Vector2i.ZERO
var edge_key: String = ""
var mesh_inst: MeshInstance3D
var body: StaticBody3D
var door_leaf: MeshInstance3D
var door_blocker: CollisionShape3D
var door_open: bool = false
var storage: Array = []                 # chest: array of {id,n,dur?}
var proc: Dictionary = {"ore_iron": 0, "ore_copper": 0, "fuel": 0, "out_iron": 0, "out_copper": 0, "t": 0.0}
var light: OmniLight3D = null
var flame: CPUParticles3D = null
var turret_head: Node3D = null
var _cd: float = 0.0
var _hazard_cd: Dictionary = {}
var footprint: Vector2 = Vector2.ONE


func setup(p_sid: String, p_yaw: float) -> void:
	sid = p_sid
	yaw = p_yaw
	var d: Dictionary = Data.structures[sid]
	kind = String(d["kind"])
	footprint = d["size"]
	rotation.y = yaw
	interact_radius = 2.8
	enabled = false
	var mid := sid
	if sid == "door":
		mid = "door_frame"
	mesh_inst = MeshInstance3D.new()
	mesh_inst.mesh = StructModels.get_mesh(mid)
	add_child(mesh_inst)
	_make_collision()
	match sid:
		"campfire":
			enabled = true
			_make_fire()
		"chest", "workbench", "cooking", "bedroll", "processor":
			enabled = true
		"door":
			enabled = true
			_make_door()
		"lamp":
			_make_lamp()
		"turret":
			_make_turret()
	if sid == "campfire" or sid == "cooking":
		if Game.world:
			Game.world.warm_sources.append([global_position, 7.0, 36.0 if sid == "campfire" else 20.0, self])
	set_physics_process(sid in ["turret", "processor", "barricade", "lamp"])


func _box(size: Vector3, pos: Vector3) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = pos
	body.add_child(cs)
	return cs


func _make_collision() -> void:
	body = StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	add_child(body)
	match sid:
		"foundation": _box(Vector3(4.0, 1.8, 4.0), Vector3(0, 0.12 - 0.9, 0))
		"floor": _box(Vector3(4.0, 0.2, 4.0), Vector3(0, 0.0, 0))
		"wall", "reinforced_wall": _box(Vector3(4.0, 3.0, 0.26), Vector3(0, 1.5, 0))
		"door":
			_box(Vector3(1.4, 3.0, 0.26), Vector3(-1.3, 1.5, 0))
			_box(Vector3(1.4, 3.0, 0.26), Vector3(1.3, 1.5, 0))
			_box(Vector3(1.5, 0.8, 0.26), Vector3(0, 2.6, 0))
		"workbench": _box(Vector3(2.2, 1.0, 1.0), Vector3(0, 0.5, 0))
		"cooking": _box(Vector3(2.0, 1.0, 1.0), Vector3(0, 0.5, 0))
		"chest": _box(Vector3(1.2, 0.9, 0.75), Vector3(0, 0.45, 0))
		"campfire": _box(Vector3(0.9, 0.4, 0.9), Vector3(0, 0.2, 0))
		"lamp": _box(Vector3(0.3, 2.4, 0.3), Vector3(0, 1.2, 0))
		"barricade": _box(Vector3(2.4, 1.2, 0.5), Vector3(0, 0.6, 0))
		"turret": _box(Vector3(0.8, 1.6, 0.8), Vector3(0, 0.8, 0))
		"processor": _box(Vector3(2.0, 1.4, 1.8), Vector3(0, 0.7, 0))
		_:
			body.queue_free()
			body = null


func _make_door() -> void:
	door_leaf = MeshInstance3D.new()
	door_leaf.mesh = StructModels.get_mesh("door_leaf")
	door_leaf.position = Vector3(-0.65, 0, 0)
	add_child(door_leaf)
	door_blocker = _box(Vector3(1.3, 2.2, 0.14), Vector3(0, 1.1, 0))


func _make_fire() -> void:
	flame = CPUParticles3D.new()
	flame.amount = 22
	flame.lifetime = 0.8
	flame.direction = Vector3.UP
	flame.spread = 12.0
	flame.initial_velocity_min = 0.7
	flame.initial_velocity_max = 1.4
	flame.gravity = Vector3(0, 1.0, 0)
	flame.scale_amount_min = 0.5
	flame.scale_amount_max = 1.2
	var sm := SphereMesh.new()
	sm.radius = 0.09
	sm.height = 0.18
	sm.radial_segments = 6
	sm.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	sm.material = mat
	flame.mesh = sm
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.85, 0.3, 1))
	g.set_color(1, Color(0.9, 0.2, 0.05, 0))
	flame.color_ramp = g
	flame.position = Vector3(0, 0.3, 0)
	add_child(flame)
	light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.65, 0.3)
	light.light_energy = 1.6
	light.omni_range = 9.0
	light.position = Vector3(0, 0.9, 0)
	light.shadow_enabled = false
	add_child(light)


func _make_lamp() -> void:
	light = OmniLight3D.new()
	light.light_color = Color(0.6, 0.95, 1.0)
	light.light_energy = 0.0
	light.omni_range = 11.0
	light.position = Vector3(0, 2.6, 0)
	add_child(light)


func _make_turret() -> void:
	turret_head = Node3D.new()
	turret_head.position = Vector3(0, 1.3, 0)
	add_child(turret_head)


func get_prompt(_p: Node) -> String:
	match sid:
		"campfire": return "Use Campfire (cook and smelt)"
		"workbench": return "Use Workbench"
		"cooking": return "Use Cooking Station"
		"chest": return "Open Storage Box"
		"door": return "Close Door" if door_open else "Open Door"
		"bedroll": return "Sleep (set respawn)"
		"processor":
			var done: int = int(proc["out_iron"]) + int(proc["out_copper"])
			if done > 0:
				return "Collect %d ingots" % done
			return "Load Processor (ore and wood)"
	return "Interact"


func can_interact(_p: Node) -> bool:
	return enabled


func interact(player: Node) -> void:
	var w: Node = Game.world
	match sid:
		"campfire", "workbench", "cooking":
			if sid == "campfire" and Game.respawn_pos.distance_to(global_position) > 3.0:
				Game.respawn_pos = global_position + Vector3(1.6, 0.3, 1.6)
				Game.toast("Respawn point set.", "info")
			Sfx.play("click")
			w.hud.panel_requested.emit("craft")
		"chest":
			w.open_storage(self)
		"door":
			set_door(not door_open)
			Game.add_stat("interact:door")
		"bedroll":
			Game.respawn_pos = global_position + Vector3(0, 0.3, 1.4)
			Game.toast("Respawn point set.", "info")
			w.sleep_at(self)
		"processor":
			_processor_interact()


func set_door(open: bool) -> void:
	door_open = open
	if door_leaf:
		var tw := create_tween()
		tw.tween_property(door_leaf, "rotation:y", deg_to_rad(-95.0) if open else 0.0, 0.25)
	if door_blocker:
		door_blocker.disabled = open
	Sfx.play_at("door", global_position, 1.0 if open else 0.85, 30.0)


func _processor_interact() -> void:
	var out_i := int(proc["out_iron"])
	var out_c := int(proc["out_copper"])
	if out_i + out_c > 0:
		if out_i > 0:
			Game.give_item("iron_ingot", out_i)
		if out_c > 0:
			Game.give_item("copper_ingot", out_c)
		proc["out_iron"] = 0
		proc["out_copper"] = 0
		Sfx.play("pickup")
		return
	var moved := 0
	for pair in [["iron_ore", "ore_iron"], ["copper_ore", "ore_copper"], ["wood", "fuel"]]:
		var n: int = Inv.count(pair[0])
		if n > 0:
			Inv.remove(pair[0], n)
			proc[pair[1]] = int(proc[pair[1]]) + n
			moved += n
	if moved > 0:
		Game.toast("Processor loaded. It smelts on its own.", "info")
		Sfx.play("craft")
	else:
		Game.toast("Bring iron ore, copper ore and wood.", "warn")


func _physics_process(delta: float) -> void:
	if not Game.is_playing():
		return
	match sid:
		"processor":
			var rate := 0.7 if Game.has_skill("en5") else 1.0
			var have_ore: bool = int(proc["ore_iron"]) + int(proc["ore_copper"]) >= 2 and int(proc["fuel"]) >= 1
			if have_ore:
				proc["t"] = float(proc["t"]) + delta
				if float(proc["t"]) >= 8.0 * rate:
					proc["t"] = 0.0
					proc["fuel"] = int(proc["fuel"]) - 1
					if int(proc["ore_iron"]) >= 2:
						proc["ore_iron"] = int(proc["ore_iron"]) - 2
						proc["out_iron"] = int(proc["out_iron"]) + 1
					else:
						proc["ore_copper"] = int(proc["ore_copper"]) - 2
						proc["out_copper"] = int(proc["out_copper"]) + 1
		"barricade":
			_cd -= delta
			if _cd <= 0.0 and Game.world:
				_cd = 0.4
				for e in Game.world.enemies_near(global_position, 2.4):
					e.take_damage(7.0, global_position, 2.0, null, false)
		"lamp":
			if light and Game.world and Game.world.sky:
				light.light_energy = lerpf(light.light_energy, 2.2 * clampf(Game.world.sky.night_amount * 1.6, 0.0, 1.0), delta * 2.0)
		"turret":
			_cd -= delta
			var w: Node = Game.world
			if w == null:
				return
			var best: Node = null
			var bd := 24.0
			for e in w.enemies_near(global_position, 24.0):
				var d: float = e.global_position.distance_to(global_position)
				if d < bd:
					bd = d
					best = e
			if best:
				var dir: Vector3 = (best.hit_center() - (global_position + Vector3(0, 1.3, 0))).normalized()
				turret_head.rotation.y = lerp_angle(turret_head.rotation.y, atan2(-dir.x, -dir.z) - rotation.y, delta * 8.0)
				if _cd <= 0.0:
					_cd = 0.84 if Game.has_skill("en5") else 1.4
					w.spawn_projectile(global_position + Vector3(0, 1.3, 0), dir, 22.0, true, 34.0, Color(0.5, 0.95, 1.0), null)
					Sfx.play_at("shot", global_position, 1.2, 40.0)


func serialize() -> Dictionary:
	var d := {"sid": sid, "x": global_position.x, "y": global_position.y, "z": global_position.z, "yaw": yaw}
	if sid == "chest":
		d["storage"] = storage
	if sid == "door":
		d["open"] = door_open
	if sid == "processor":
		d["proc"] = proc
	return d


func restore_state(d: Dictionary) -> void:
	if sid == "chest":
		storage = d.get("storage", [])
	if sid == "door" and bool(d.get("open", false)):
		set_door(true)
		door_leaf.rotation.y = deg_to_rad(-95.0)
	if sid == "processor":
		var p: Dictionary = d.get("proc", {})
		for k in proc:
			if p.has(k):
				proc[k] = p[k]


func _exit_tree() -> void:
	super._exit_tree()
	if Game.world and is_instance_valid(Game.world):
		for w in Game.world.warm_sources.duplicate():
			if w.size() > 3 and w[3] == self:
				Game.world.warm_sources.erase(w)
