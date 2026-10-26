extends Node
const World = preload("res://scripts/world/world.gd")
var ok := 0
var bad := 0
func check(c: bool, l: String) -> void:
	if c: ok += 1; print("  ok   - ", l)
	else: bad += 1; print("  FAIL - ", l)
func _ready():
	Game.reset_progress(); Inv.clear(); Quests.reset()
	var w = World.new()
	add_child(w)
	w.build(false)
	await w.loaded
	Game.state = Game.State.PLAY
	var p = w.player
	for bid in ["grove_guardian", "furnace_colossus", "core_architect"]:
		var b = null
		for e in w.enemies:
			if e.get("bid") == bid: b = e
		check(b != null, bid + " exists in world")
		if b == null: continue
		var c: Vector3 = b.arena_c
		p.place_at(Vector3(c.x + 14, c.y + 2, c.z))
		var seen := {}
		var hurt := 0
		var last_hp: float = Game.health
		for i in 60 * 40:
			await get_tree().physics_frame
			if Game.health < Game.max_health * 0.5: Game.health = Game.max_health
			if Game.health < last_hp - 0.5: hurt += 1
			last_hp = Game.health
			seen[b._atk] = true
			if i == 120:
				check(b.state != "dormant", bid + " wakes when player enters arena (state %s)" % b.state)
			if i > 300 and i % 150 == 0 and b.alive:
				b.take_damage(b.max_hp * 0.12, p.global_position, 0.0, p, false)
				if b.shield:
					for a in b.adds:
						if is_instance_valid(a) and a.alive: a.hp = 1.0; a.take_damage(50.0, p.global_position, 0.0, p, false)
			if not b.alive: break
		print("  attacks seen: ", seen.keys(), " hits taken: ", hurt, " phase ", b.phase)
		check(not b.alive, bid + " can be defeated")
		check(Game.bosses_defeated.has(bid), bid + " recorded as defeated")
		check(hurt > 0, bid + " damaged the player")
		check(seen.size() >= 3, bid + " used at least 3 attacks")
	print("boss checks: %d passed, %d failed" % [ok, bad])
	get_tree().quit()
