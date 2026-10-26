extends "res://scripts/world/interactable.gd"
## A harvestable world object (tree, rock, ore, plant). Visual is a MultiMesh instance owned by Decor.

const WG = preload("res://scripts/world/world_gen.gd")

var rid: String = ""
var def: Dictionary = {}
var hits_left: float = 1.0
var depleted: bool = false
var respawn_at: float = 0.0       # play_seconds when it comes back
var handle = null                 # Decor.Handle
var node_id: int = -1             # stable index for saves
var body: StaticBody3D = null
var shake_t: float = 0.0
var base_xf: Transform3D


func setup(id: String, d: Dictionary, nid: int) -> void:
	rid = id
	def = d
	node_id = nid
	hits_left = float(d["hits"])
	hold_repeat = true
	interact_radius = 1.9 + float(d["radius"])
	aim_offset = Vector3(0, 0.8, 0)


func set_collision(on: bool) -> void:
	if not def.has("tree") and float(def["radius"]) < 0.8:
		return
	if on and body == null and not depleted:
		body = StaticBody3D.new()
		body.collision_layer = 2
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = float(def["radius"]) * (0.6 if def.has("tree") else 0.9)
		cyl.height = 4.0 if def.has("tree") else 2.0
		cs.shape = cyl
		cs.position.y = cyl.height * 0.5
		body.add_child(cs)
		add_child(body)
	elif not on and body != null:
		body.queue_free()
		body = null


func _tool_ok(player: Node) -> bool:
	var tool := String(def["tool"])
	if tool == "":
		return true
	var i: int = Inv.best_tool(tool)
	if i < 0:
		return false
	return int(Data.items[Inv.slots[i]["id"]].get("tier", 0)) >= int(def["tier"])


func get_prompt(player: Node) -> String:
	var tool := String(def["tool"])
	var n := String(def["name"])
	if tool == "":
		return "Gather %s" % n
	if Inv.best_tool(tool) < 0:
		return "%s (needs %s)" % [n, "an axe" if tool == "axe" else "a pickaxe"]
	if not _tool_ok(player):
		return "%s (needs a better pickaxe)" % n
	return ("Chop %s" if tool == "axe" else "Mine %s") % n


func can_interact(_player: Node) -> bool:
	return enabled and not depleted


func interact(player: Node) -> void:
	start_gather(player)


func start_gather(player: Node) -> void:
	if depleted:
		return
	if not _tool_ok(player):
		var tool := String(def["tool"])
		Sfx.play("invalid")
		if Inv.best_tool(tool) < 0:
			Game.toast("You need %s to harvest this. Craft one first." % ("an axe" if tool == "axe" else "a pickaxe"), "warn")
		else:
			Game.toast("Your pickaxe is too weak for this. Craft a better one.", "warn")
		return
	var kind := "pluck"
	if String(def["tool"]) == "axe":
		kind = "chop"
	elif String(def["tool"]) == "pick":
		kind = "mine"
	player.begin_gather(self, kind)


func apply_gather(player: Node) -> void:
	if depleted:
		return
	var tool := String(def["tool"])
	var dmg := 1.0
	if tool != "":
		var i: int = Inv.best_tool(tool)
		dmg = float(Data.items[Inv.slots[i]["id"]].get("power", 1.0))
		Inv.damage_slot(i, 1)
	hits_left -= dmg
	shake_t = 0.3
	var snd := "pluck"
	if tool == "axe":
		snd = "chop"
	elif tool == "pick":
		snd = "mine"
	Sfx.play_at(snd, global_position, randf_range(0.92, 1.08), 40.0)
	if Game.world:
		var c := Color(0.55, 0.4, 0.25) if tool == "axe" else (Color(0.7, 0.7, 0.7) if tool == "pick" else Color(0.4, 0.8, 0.3))
		Game.world.spawn_burst(global_position + Vector3(0, 1.0, 0), c, 6, 2.5)
	if hits_left <= 0:
		_harvest(player)


func _harvest(_player: Node) -> void:
	var mult := 1.25 if Game.has_skill("sv1") else 1.0
	var got := {}
	for d in def["drops"]:
		var n := int(round(randf_range(float(d[1]), float(d[2]) + 0.99) * mult))
		n = clampi(n, int(d[1]), 99)
		if n > 0:
			got[d[0]] = got.get(d[0], 0) + n
	for id in got.keys():
		Game.give_item(id, int(got[id]))
		Game.add_stat("gather:" + String(id), int(got[id]))
		Game.toast("+%d %s" % [int(got[id]), Data.item_name(id)], "item")
	Game.add_stat("gather_nodes")
	if String(def["tool"]) == "axe":
		Game.add_stat("trees_felled")
	if String(def["tool"]) == "pick":
		Game.add_stat("rocks_mined")
	Game.add_xp(2 + int(def["tier"]) * 2 + (3 if String(def["tool"]) != "" else 0))
	deplete(true)


func deplete(announce: bool) -> void:
	depleted = true
	enabled = false
	respawn_at = Game.play_seconds + float(def["respawn"])
	if handle:
		handle.set_visible_inst(false)
	set_collision(false)
	if announce and Game.world:
		Game.world.spawn_burst(global_position + Vector3(0, 0.8, 0), Color(0.6, 0.55, 0.4), 10, 3.0)


func restore() -> void:
	depleted = false
	enabled = true
	hits_left = float(def["hits"])
	if handle:
		handle.set_visible_inst(true)


func tick(_delta: float) -> void:
	if depleted and Game.play_seconds >= respawn_at:
		# do not respawn on top of the player
		if Game.world and Game.world.player and Game.world.player.global_position.distance_to(global_position) < 4.0:
			respawn_at += 5.0
			return
		restore()
