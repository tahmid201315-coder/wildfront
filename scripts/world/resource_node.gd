extends Node3D
## A gatherable world object (tree, rock, bush...). It has no per-frame processing;
## the world ticks respawn timers centrally.

const CM = preload("res://scripts/creatures/creature_model.gd")

const KINDS := {
	"tree": {"item": "wood", "yield": 3, "hits": 3, "respawn": 240.0, "verb": "Chop", "name": "Tree", "radius": 0.5, "bonus_tool": true, "sound": "chop"},
	"rock": {"item": "stone", "yield": 2, "hits": 3, "respawn": 240.0, "verb": "Mine", "name": "Boulder", "radius": 0.9, "bonus_tool": true, "sound": "chop"},
	"fiber": {"item": "fiber", "yield": 2, "hits": 1, "respawn": 90.0, "verb": "Gather", "name": "Fiber Bush", "radius": 0.5, "bonus_tool": false, "sound": "gather"},
	"berry": {"item": "berries", "yield": 3, "hits": 1, "respawn": 120.0, "verb": "Pick", "name": "Sunberry Bush", "radius": 0.5, "bonus_tool": false, "sound": "gather"},
	"herb": {"item": "herb", "yield": 2, "hits": 1, "respawn": 150.0, "verb": "Gather", "name": "Meadow Herbs", "radius": 0.4, "bonus_tool": false, "sound": "gather"},
	"ore": {"item": "ore", "yield": 2, "hits": 4, "respawn": 300.0, "verb": "Mine", "name": "Rust Ore Vein", "radius": 0.9, "bonus_tool": true, "sound": "chop"},
	"crystal": {"item": "crystal", "yield": 1, "hits": 5, "respawn": 600.0, "verb": "Mine", "name": "Aether Crystal", "radius": 0.7, "bonus_tool": false, "sound": "chop"},
	"shard": {"item": "ember_shard", "yield": 1, "hits": 3, "respawn": 420.0, "verb": "Collect", "name": "Ember Shard Formation", "radius": 0.7, "bonus_tool": false, "sound": "chop"},
}

var rid: String = ""
var kind: String = "tree"
var info: Dictionary = {}
var hits_left: int = 3
var depleted: bool = false
var respawn_left: float = 0.0
var ember_variant: bool = false
var world: Node = null
var visual: Node3D
var marker: MeshInstance3D
var body: StaticBody3D
var interact_radius: float = 3.0
var _busy: bool = false


func setup(p_world: Node, p_id: String, p_kind: String, pos: Vector3, ember: bool, rot: float, sc: float) -> void:
	world = p_world
	rid = p_id
	kind = p_kind
	info = KINDS[kind]
	ember_variant = ember
	hits_left = int(info["hits"])
	position = pos
	rotation.y = rot
	add_to_group("interactable")
	add_to_group("resource")
	visual = Node3D.new()
	visual.scale = Vector3.ONE * sc
	add_child(visual)
	_build_visual()
	body = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = float(info["radius"]) * sc * (0.55 if kind == "tree" else 0.9)
	shape.height = 2.0
	cs.shape = shape
	cs.position.y = 1.0
	body.add_child(cs)
	add_child(body)
	# glowing "sniff" marker (hidden until revealed by a companion ability)
	marker = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.18
	sm.height = 0.36
	sm.radial_segments = 8
	sm.rings = 4
	marker.mesh = sm
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(1.0, 0.95, 0.4)
	mm.emission_enabled = true
	mm.emission = Color(1.0, 0.9, 0.3)
	mm.emission_energy_multiplier = 3.0
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.material_override = mm
	marker.position.y = 2.6 * sc
	marker.visible = false
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(marker)


func _build_visual() -> void:
	var leaf_col := Color(0.25, 0.6, 0.3) if not ember_variant else Color(0.8, 0.35, 0.15)
	var wood_col := Color(0.45, 0.3, 0.18) if not ember_variant else Color(0.25, 0.18, 0.15)
	match kind:
		"tree":
			var trunk := CM.part(visual, "cyl", Vector3(0.45, 2.2, 0.45), wood_col, Vector3(0, 1.1, 0))
			trunk.name = "Trunk"
			var can := Node3D.new()
			can.name = "Canopy"
			visual.add_child(can)
			if ember_variant:
				CM.part(can, "cone", Vector3(2.0, 2.4, 2.0), leaf_col, Vector3(0, 3.0, 0))
				CM.part(can, "cone", Vector3(1.4, 1.6, 1.4), leaf_col.lightened(0.15), Vector3(0, 4.0, 0))
			else:
				CM.part(can, "sphere", Vector3(2.4, 2.0, 2.4), leaf_col, Vector3(0, 3.0, 0))
				CM.part(can, "sphere", Vector3(1.6, 1.4, 1.6), leaf_col.lightened(0.12), Vector3(0.3, 3.9, 0.1))
		"rock":
			var c := Color(0.55, 0.57, 0.6) if not ember_variant else Color(0.4, 0.3, 0.28)
			CM.part(visual, "sphere", Vector3(1.8, 1.2, 1.5), c, Vector3(0, 0.45, 0), Vector3(0, 20, 0))
			CM.part(visual, "sphere", Vector3(1.0, 0.8, 0.9), c.lightened(0.1), Vector3(0.6, 0.3, 0.4))
		"fiber":
			for i in 5:
				var a := TAU * i / 5.0
				CM.part(visual, "cone", Vector3(0.18, 0.9, 0.18), Color(0.55, 0.78, 0.3), Vector3(cos(a) * 0.25, 0.45, sin(a) * 0.25), Vector3(sin(a) * 18, 0, -cos(a) * 18))
		"berry":
			CM.part(visual, "sphere", Vector3(1.1, 0.8, 1.1), Color(0.2, 0.5, 0.25), Vector3(0, 0.4, 0))
			for i in 6:
				var a2 := TAU * i / 6.0
				CM.part(visual, "sphere", Vector3(0.14, 0.14, 0.14), Color(0.9, 0.15, 0.25), Vector3(cos(a2) * 0.5, 0.5 + (i % 2) * 0.2, sin(a2) * 0.5), Vector3.ZERO, 0.3)
		"herb":
			for i in 4:
				var a3 := TAU * i / 4.0
				CM.part(visual, "sphere", Vector3(0.3, 0.1, 0.5), Color(0.3, 0.75, 0.5), Vector3(cos(a3) * 0.25, 0.25, sin(a3) * 0.25), Vector3(0, -rad_to_deg(a3), 30))
			CM.part(visual, "sphere", Vector3(0.14, 0.14, 0.14), Color(0.9, 0.9, 1.0), Vector3(0, 0.5, 0), Vector3.ZERO, 1.0)
		"ore":
			CM.part(visual, "sphere", Vector3(1.6, 1.1, 1.4), Color(0.35, 0.28, 0.27), Vector3(0, 0.4, 0))
			for i in 5:
				var a4 := TAU * i / 5.0
				CM.part(visual, "box", Vector3(0.28, 0.28, 0.28), Color(0.85, 0.45, 0.25), Vector3(cos(a4) * 0.55, 0.5 + (i % 3) * 0.2, sin(a4) * 0.5), Vector3(i * 20, i * 35, 10), 0.4)
		"crystal":
			var cc := Color(0.5, 0.85, 1.0)
			for i in 4:
				var a5 := TAU * i / 4.0
				CM.part(visual, "cone", Vector3(0.45, 1.2 + (i % 2) * 0.6, 0.45), cc, Vector3(cos(a5) * 0.35, 0.7, sin(a5) * 0.35), Vector3(cos(a5) * 15, 0, sin(a5) * 15), 1.6)
			CM.part(visual, "cone", Vector3(0.55, 1.9, 0.55), cc.lightened(0.3), Vector3(0, 1.0, 0), Vector3.ZERO, 2.0)
		"shard":
			var sc2 := Color(1.0, 0.55, 0.15)
			CM.part(visual, "sphere", Vector3(1.3, 0.6, 1.3), Color(0.3, 0.22, 0.2), Vector3(0, 0.25, 0))
			for i in 3:
				var a6 := TAU * i / 3.0
				CM.part(visual, "cone", Vector3(0.35, 1.1, 0.35), sc2, Vector3(cos(a6) * 0.3, 0.9, sin(a6) * 0.3), Vector3(cos(a6) * 20, 0, sin(a6) * 20), 2.2)


# ------------------------------------------------------------ interactable interface
func get_prompt() -> String:
	if depleted:
		return ""
	return "%s %s" % [info["verb"], info["name"]]


func can_interact(_player: Node) -> bool:
	return not depleted and not _busy


func interact(player: Node) -> void:
	if not can_interact(player):
		return
	if player.has_method("begin_gather"):
		_busy = true
		player.begin_gather(self)


func finish_busy() -> void:
	_busy = false


## Apply one gather hit. Returns true when a reward was granted.
func apply_gather(player: Node, skip_distance: bool = false) -> bool:
	if depleted or hits_left <= 0:
		_busy = false
		return false
	if not skip_distance and player != null:
		if player.global_position.distance_to(global_position) > interact_radius + 1.5:
			_busy = false
			return false
	var total: int = int(info["yield"])
	var item: String = info["item"]
	if info["bonus_tool"] and Inv.count("stone_axe") > 0:
		total += 1
	var comp: Dictionary = Game.active_creature()
	if not comp.is_empty() and comp["species"] == "bramblehog" and item in ["wood", "stone", "fiber"]:
		total += 1
	var hits: int = int(info["hits"])
	var per_hit: int = total / hits
	var index: int = hits - hits_left
	var amount: int = per_hit + (total - per_hit * hits if index == hits - 1 else 0)
	amount = maxi(amount, 1) if index == hits - 1 else amount
	hits_left -= 1
	if amount > 0:
		var left: int = Inv.add(item, amount)
		if left > 0:
			Game.give_item(item, left)  # drops a pickup near the player
		Quests.notify_event("gather", item, amount)
		if world:
			world.float_text(global_position + Vector3(0, 2.2, 0), "+%d %s" % [amount, Data.item_name(item)])
	if randf() < 0.08 and kind == "berry":
		Game.give_item("seed_berry", 1)
		Game.toast("Found a Sunberry Seed!", "info")
	if kind == "shard" and randf() < 0.3:
		Game.give_item("ember_shard", 1)
		Quests.notify_event("gather", "ember_shard", 1)
	Sfx.play(str(info["sound"]), randf_range(0.9, 1.1))
	if world:
		world.spawn_burst(global_position + Vector3(0, 1.0, 0), Color(visual_color()), 6)
	if hits_left <= 0:
		_deplete()
	else:
		_shake()
	_busy = false
	var c := Game.active_uid
	if c != "":
		Game.creature_add_xp(c, 1)
	return true


func visual_color() -> Color:
	return Data.get_item(info["item"]).get("color", Color.WHITE)


func _shake() -> void:
	var tw := create_tween()
	tw.tween_property(visual, "rotation:z", 0.08, 0.05)
	tw.tween_property(visual, "rotation:z", -0.06, 0.07)
	tw.tween_property(visual, "rotation:z", 0.0, 0.07)


func _deplete() -> void:
	depleted = true
	respawn_left = float(info["respawn"])
	_set_depleted_visual(true)
	if world:
		world.register_depleted(self)


func _set_depleted_visual(dep: bool) -> void:
	if kind == "tree":
		var can := visual.get_node_or_null("Canopy")
		if can:
			can.visible = not dep
		var trunk := visual.get_node_or_null("Trunk")
		if trunk:
			trunk.scale.y = 0.35 if dep else 2.2
			trunk.position.y = 0.2 if dep else 1.1
	else:
		visual.visible = not dep
	if body:
		for c in body.get_children():
			if c is CollisionShape3D:
				c.set_deferred("disabled", dep)
	if world:
		world.set_obstacle_active(self, not dep)
	if marker and dep:
		marker.visible = false


func respawn() -> void:
	depleted = false
	hits_left = int(info["hits"])
	respawn_left = 0.0
	_set_depleted_visual(false)


func restore_depleted(seconds_left: float) -> void:
	depleted = true
	hits_left = 0
	respawn_left = seconds_left
	_set_depleted_visual(true)
