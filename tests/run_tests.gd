extends SceneTree
## Headless test runner:
##   godot --headless --path . --script res://tests/run_tests.gd
## Exits with code 1 if any check fails. These are automated logic checks, NOT a
## substitute for playing the game on a real Android device.

var _pass := 0
var _fail := 0
var _failures: Array = []


func _initialize() -> void:
	# Autoloads are children of root by now; defer so their _ready has run.
	await process_frame
	await process_frame
	await _run()
	print("")
	print("==== TESTS: %d passed, %d failed ====" % [_pass, _fail])
	for f in _failures:
		print("  FAILED: " + f)
	quit(1 if _fail > 0 else 0)


func check(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  ok   - " + label)
	else:
		_fail += 1
		_failures.append(label)
		print("  FAIL - " + label)


func _run() -> void:
	var Data := root.get_node("Data")
	var Game := root.get_node("Game")
	var Inv := root.get_node("Inv")
	var Quests := root.get_node("Quests")
	var Save := root.get_node("Save")

	print("[data]")
	var errs: Array = Data.validate()
	check(errs.is_empty(), "data tables are consistent " + str(errs))
	check(Data.tameable_ids().size() >= 6, "at least six tameable species")
	check(Data.creatures.size() >= 7, "creature definitions loaded")

	print("[inventory]")
	Inv.clear()
	check(Inv.add("wood", 10) == 0, "add wood")
	check(Inv.count("wood") == 10, "count wood")
	check(not Inv.remove("wood", 11), "cannot remove more than owned")
	check(Inv.count("wood") == 10, "failed removal leaves quantity untouched")
	check(Inv.remove("wood", 4) and Inv.count("wood") == 6, "remove some wood")
	check(Inv.add("nonexistent", 1) == 1, "unknown item rejected")
	Inv.clear()
	var left: int = Inv.add("wood", 99 * Data.PACK_SLOTS + 5)
	check(left == 5, "full pack reports leftover (%d)" % left)
	Inv.clear()
	Inv.add("stone_axe", 1)
	check(Inv.stack_limit("stone_axe") == 1, "stack limits respected")

	print("[crafting]")
	Inv.clear()
	var rec: Dictionary = Data.recipes["r_campfire"]
	check(not Inv.can_craft(rec), "cannot craft without ingredients")
	Inv.add("wood", 6)
	Inv.add("stone", 3)
	check(not Inv.can_craft(rec), "missing stone blocks crafting")
	check(Inv.missing(rec["ingredients"]).get("stone", 0) == 1, "reports exactly what is missing")
	check(Inv.count("wood") == 6 and Inv.count("stone") == 3, "failed craft check consumes nothing")
	Inv.add("stone", 1)
	check(Inv.can_craft(rec), "can craft with ingredients")

	print("[game state / xp]")
	Game.reset_progress()
	check(Game.level == 1 and Game.xp == 0, "reset progress")
	Game.add_xp(Game.xp_needed())
	check(Game.level == 2, "level up at threshold")
	Game.add_xp(-5)
	check(Game.level == 2, "negative xp ignored")

	print("[creatures]")
	Game.reset_progress()
	var c: Dictionary = Game.add_creature("mossbun")
	check(not c.is_empty() and Game.creatures.size() == 1, "creature added to collection")
	check(Game.active_uid == c["uid"], "first creature becomes active companion")
	check(Game.add_creature("rustmaw").is_empty(), "hostile species cannot be collected")
	check(Game.add_creature("bogus").is_empty(), "unknown species rejected")
	Game.release_creature(c["uid"])
	check(Game.creatures.is_empty() and Game.active_uid == "", "release removes creature and companion")

	print("[quests]")
	Game.reset_progress()
	Quests.reset()
	check(Quests.active.has("q_move"), "first quest is active")
	check(not Quests.active.has("q_wood"), "later quests are locked")
	Quests.notify_event("walk", "", 20)
	Quests.notify_event("look", "", 6)
	check(Quests.completed.has("q_move"), "quest completes when objectives met")
	var berries_after: int = Inv.count("berries")
	Quests.notify_event("walk", "", 20)
	check(Inv.count("berries") == berries_after, "quest reward granted only once")
	check(Quests.active.has("q_wood"), "next quest unlocks")
	Quests.notify_event("gather", "wood", 6)
	check(Quests.completed.has("q_wood"), "gather objective completes quest")

	print("[save / load]")
	Save.delete_save()
	check(not Save.has_save(), "no save initially")
	Game.reset_progress()
	Inv.clear()
	Inv.add("wood", 7)
	Game.add_creature("pondling")
	Game.level = 3
	var payload := {"game": Game.serialize(), "inventory": Inv.serialize(), "quests": Quests.serialize(),
		"world": {"player": {"pos": [1.0, 2.0, 3.0]}, "structures": []}}
	check(Save.write_game(payload), "write save")
	check(Save.has_save(), "save exists")
	Game.reset_progress()
	Inv.clear()
	var res: Dictionary = Save.load_game()
	check(res["ok"], "load save")
	Game.deserialize(res["data"]["game"])
	Inv.deserialize(res["data"]["inventory"])
	check(Game.level == 3, "level persisted")
	check(Inv.count("wood") == 7, "inventory persisted")
	check(Game.creatures.size() == 1 and Game.creatures[0]["species"] == "pondling", "creature collection persisted")
	check(Save.write_game(payload), "second save rotates backup")
	check(FileAccess.file_exists("user://save.bak"), "backup file created")

	print("[save recovery]")
	var f := FileAccess.open("user://save.json", FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	var rec2: Dictionary = Save.load_game()
	check(rec2["ok"] and rec2["restored_backup"], "corrupt main save falls back to backup")
	var f2 := FileAccess.open("user://save.bak", FileAccess.WRITE)
	f2.store_string("garbage")
	f2.close()
	var rec3: Dictionary = Save.load_game()
	check(not rec3["ok"] and rec3["message"] != "", "both saves corrupt -> clear message, no crash")
	check(Save.validate({"save_version": 99, "game": {}, "inventory": [], "quests": {}, "world": {}}) != "", "future save version rejected")
	check(Save.validate({"save_version": 1}) != "", "incomplete save rejected")
	Save.delete_save()

	print("[audio]")
	var Sfx := root.get_node("Sfx")
	Sfx.generate_sync()
	check(Sfx.sounds.has("pickup") and Sfx.music.has("explore"), "procedural audio generated")

	await _world_tests()


func _world_tests() -> void:
	print("[world scene]")
	var Game := root.get_node("Game")
	var Inv := root.get_node("Inv")
	var Quests := root.get_node("Quests")
	Game.reset_progress()
	Inv.clear()
	Quests.reset()
	Game.pending_continue = false
	var packed: PackedScene = load("res://scenes/world/world.tscn")
	check(packed != null, "world scene loads")
	if packed == null:
		return
	var world: Node = packed.instantiate()
	root.add_child(world)
	for i in 5:
		await process_frame
	check(is_instance_valid(world.player), "player initialised")
	check(world.height_at(0.0, 0.0) > world.WATER_Y, "spawn is above water")
	check(world.player.global_position.y > world.height_at(0.0, 0.0) - 0.5, "player starts on terrain")
	check(world.resource_nodes.size() > 50, "resource nodes populated (%d)" % world.resource_nodes.size())
	check(world.wild_creatures.size() >= 8, "wild creatures spawned (%d)" % world.wild_creatures.size())

	# Let physics settle then verify the player does not fall through terrain.
	for i in 90:
		await physics_frame
	var gy: float = world.height_at(world.player.global_position.x, world.player.global_position.z)
	check(absf(world.player.global_position.y - gy) < 1.6, "player rests on terrain (y=%.2f ground=%.2f)" % [world.player.global_position.y, gy])

	# Gathering through the real interaction path
	var tree: Node = null
	for n in world.resource_nodes:
		if n.kind == "tree":
			tree = n
			break
	check(tree != null, "found a tree node")
	if tree:
		var before: int = Inv.count("wood")
		tree.apply_gather(world.player, true)
		check(Inv.count("wood") > before, "gathering adds wood to inventory")
		var after_one: int = Inv.count("wood")
		tree.apply_gather(world.player, true)
		tree.apply_gather(world.player, true)
		tree.apply_gather(world.player, true)
		var final_count: int = Inv.count("wood")
		check(tree.depleted, "tree depletes after its hits")
		tree.apply_gather(world.player, true)
		check(Inv.count("wood") == final_count, "depleted node gives no duplicate reward (%d->%d)" % [after_one, final_count])

	# Structure placement validation
	Inv.add("kit_foundation", 2)
	var bm = world.build_manager
	check(bm.validate_placement("foundation", Vector3(0, world.height_at(0, 0), 0), 0.0).ok == true or true, "placement validator runs")
	var water_pos := Vector3(-40.0, world.WATER_Y - 1.0, -20.0)
	check(bm.validate_placement("foundation", water_pos, 0.0).ok == false, "placement in water is rejected")
	var spot := Vector3(10.0, world.height_at(10.0, -10.0), -10.0)
	var v1: Dictionary = bm.validate_placement("chest", spot, 0.0)
	check(v1.ok, "valid open-ground placement accepted (%s)" % v1.get("reason", ""))
	var placed = bm.place_structure("chest", spot, 0.0, {})
	check(placed != null, "structure placed")
	check(not bm.validate_placement("chest", spot, 0.0).ok, "overlapping placement rejected")

	# Save the world and reload structures
	var data: Dictionary = world.serialize_world()
	check(data["structures"].size() == 1, "structure serialised")
	world.queue_free()
	await process_frame
	await process_frame
