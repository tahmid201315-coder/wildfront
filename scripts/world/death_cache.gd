extends RefCounted
## Items dropped on death. One cache exists at a time; its contents persist in Game.death_cache.

const Interactable = preload("res://scripts/world/interactable.gd")
const MK = preload("res://scripts/gfx/mesh_kit.gd")
const WG = preload("res://scripts/world/world_gen.gd")


class CacheNode extends Interactable:
	func _ready() -> void:
		interact_radius = 3.0
		var b := MK.Builder.new(77)
		b.cyl(0.5, 0.4, 0.25, Color(0.3, 0.28, 0.3), Vector3.ZERO, Vector3.ZERO, 8)
		b.cone(0.18, 1.2, Color(0.8, 0.3, 0.3), Vector3(0, 0.25, 0), Vector3.ZERO, 5)
		b.sphere(Vector3(0.3, 0.3, 0.3), Color(0.95, 0.85, 0.5), Vector3(0, 1.55, 0), Vector3.ZERO, 4, 8)
		var mi := MeshInstance3D.new()
		mi.mesh = b.commit(MK.style_material(0.0, 0.2, 0.6))
		add_child(mi)
		var l := OmniLight3D.new()
		l.light_color = Color(1, 0.7, 0.4)
		l.light_energy = 0.8
		l.omni_range = 7.0
		l.position = Vector3(0, 1.5, 0)
		add_child(l)

	func get_prompt(_p: Node) -> String:
		return "Recover Death Cache"

	func interact(_p: Node) -> void:
		var left: Array = []
		var got := 0
		for e in Game.death_cache.get("items", []):
			if Inv.add_entry(e.duplicate()):
				got += 1
			else:
				left.append(e)
		Sfx.play("pickup")
		if left.is_empty():
			Game.death_cache = {}
			Game.toast("Recovered your belongings.", "item")
			queue_free()
		else:
			Game.death_cache["items"] = left
			Game.toast("Pack full. Some items remain in the cache.", "warn")


## Drops half of each stack (single items stay with the player). Returns the cache dictionary.
static func drop_items(world: Node) -> Dictionary:
	var drop: Array = Game.death_cache.get("items", []).duplicate()
	for i in Inv.slots.size():
		var e: Dictionary = Inv.slots[i]
		if e.is_empty():
			continue
		var n := int(e.get("n", 1))
		var d := n / 2
		if d <= 0:
			continue
		var out := e.duplicate()
		out["n"] = d
		drop.append(out)
		Inv.remove(String(e["id"]), d)
	var p: Vector3 = world.player.global_position
	Game.death_cache = {"pos": [p.x, p.y, p.z], "items": drop}
	return Game.death_cache


static func spawn_existing(world: Node) -> void:
	if world.get("death_node") and is_instance_valid(world.death_node):
		world.death_node.queue_free()
		world.death_node = null
	var c: Dictionary = Game.death_cache
	if c.is_empty() or c.get("items", []).is_empty():
		return
	var pos: Array = c["pos"]
	var n := CacheNode.new()
	world.add_child(n)
	n.global_position = Vector3(float(pos[0]), maxf(WG.height_at(float(pos[0]), float(pos[2])), 0.3), float(pos[2]))
	world.death_node = n
