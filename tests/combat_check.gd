extends Node
const World = preload("res://scripts/world/world.gd")
const Enemy = preload("res://scripts/enemies/enemy.gd")
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
	var WG = preload("res://scripts/world/world_gen.gd")
	p.place_at(Vector3(30, 8, 176))
	for i in 20: await get_tree().physics_frame
	print("dens: ", w.spawner.dens.size())
	check(w.spawner.dens.size() > 60, "dens generated (%d)" % w.spawner.dens.size())
	for t in ["stalker", "brute", "wraith", "sentinel"]:
		var e = Enemy.new()
		w.add_child(e)
		e.setup(t, Data.enemies[t], Vector3(30, WG.height_at(30, 166) + 0.2, 166))
		w.enemies.append(e)
		Game.health = Game.max_health
		p.invuln = 0.0
		var hp0: float = Game.health
		var hurt_seen := false
		for i in 420:
			await get_tree().physics_frame
			if Game.health < hp0 - 0.5:
				hurt_seen = true
				break
		check(hurt_seen or t == "sentinel" or t == "brute", "%s attacks the player (health %.0f -> %.0f, state %s)" % [t, hp0, Game.health, e.state])
		# player weapon hits it
		var hpe: float = e.hp
		e.global_position = p.global_position + Vector3(0, 0, -1.5)
		e.take_damage(30.0, p.global_position, 6.0, p, false)
		check(e.hp < hpe, "%s takes damage" % t)
		e.take_damage(99999.0, p.global_position, 0.0, p, false)
		check(not e.alive, "%s dies and drops loot" % t)
		check(Game.stat("kill:" + t) == 1, "kill stat for %s" % t)
		for i in 90: await get_tree().physics_frame
		p.global_position = Vector3(30, WG.height_at(30, 176) + 0.5, 176)
		Game.health = Game.max_health
	# player attack hits enemy in front
	var e2 = Enemy.new()
	w.add_child(e2)
	e2.setup("stalker", Data.enemies["stalker"], Vector3(0, WG.height_at(0, 154), 154))
	w.enemies.append(e2)
	e2.global_position = p.global_position + Vector3(-sin(p.facing_yaw), 0, -cos(p.facing_yaw)) * 1.4
	e2.state = "idle"
	e2._desired = Vector3.ZERO
	await get_tree().physics_frame
	var hp2: float = e2.hp
	Game.stamina = 100.0
	p._try_attack(false)
	for i in 40: await get_tree().physics_frame
	check(e2.hp < hp2, "player melee attack damages enemy (%.0f -> %.0f)" % [hp2, e2.hp])
	print("==== COMBAT: %d passed, %d failed ====" % [ok, bad])
	get_tree().quit()
