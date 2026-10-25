extends SceneTree
## Headless logic tests: godot --headless --path . --script res://tests/run_tests.gd
## These are automated logic checks, NOT a substitute for playing on a real device.

var _pass := 0
var _fail := 0
var _failures: Array = []


func _initialize() -> void:
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
	var WG = load("res://scripts/world/world_gen.gd")
	var DW = load("res://scripts/core/data_world.gd")

	print("[data]")
	var errs: Array = Data.validate()
	check(errs.is_empty(), "data tables are consistent " + str(errs))
	check(Data.items.size() >= 40, "items loaded (%d)" % Data.items.size())
	check(Data.recipes.size() >= 20, "recipes loaded (%d)" % Data.recipes.size())
	check(Data.quests.size() >= 20, "quests loaded (%d)" % Data.quests.size())
	check(Data.bosses.size() == 3, "three bosses defined")
	check(Data.enemies.size() == 4, "four enemy types defined")

	print("[inventory]")
	Game.reset_progress()
	Inv.clear()
	check(Inv.add("wood", 10) == 0, "add wood")
	check(Inv.count("wood") == 10, "count wood")
	check(not Inv.remove("wood", 11), "cannot remove more than owned")
	check(Inv.count("wood") == 10, "failed removal leaves quantity untouched")
	check(Inv.remove("wood", 4) and Inv.count("wood") == 6, "remove some wood")
	check(Inv.add("nonexistent", 1) == 1, "unknown item rejected")
	Inv.clear()
	var cap: int = Inv.capacity()
	var left: int = Inv.add("wood", 999999)
	check(left > 0 and Inv.count("wood") + left == 999999, "full pack reports leftover without losing items (%d slots)" % cap)
	Inv.clear()

	print("[world generation]")
	WG.setup(1337)
	WG.build_grid()
	var h0: float = WG.height_at(DW.START_POS.x, DW.START_POS.y)
	check(h0 > 1.0, "start position is on land (h=%.1f)" % h0)
	var water_found := false
	for x in range(-250, 250, 25):
		if WG.height_at(x, 250) < 0.0:
			water_found = true
	check(water_found, "island is surrounded by water")
	for k in DW.SITES:
		var s: Dictionary = DW.SITES[k]
		var h: float = WG.height_at(s["pos"].x, s["pos"].y)
		check(h > 0.5, "site '%s' is above sea level (h=%.1f)" % [k, h])
		check(WG.region_at(s["pos"].x, s["pos"].y) == s["region"], "site '%s' lies in region %s" % [k, s["region"]])

	print("[progression]")
	Game.reset_progress()
	Quests.reset()
	check(Quests.active_ids().size() >= 1, "a first quest is active on a new game")
	var xp0: int = Game.xp
	Game.add_xp(Game.xp_needed() + 1)
	check(Game.level == 2 and Game.skill_points >= 1, "levelling up grants a skill point")
	check(Game.xp != xp0 or Game.level == 2, "xp progresses")
	var sp: int = Game.skill_points
	check(Game.learn_skill("sv1") and Game.skill_points == sp - 1, "skill can be learned")
	check(not Game.learn_skill("sv3"), "skill with missing prerequisite is refused")

	print("[save system]")
	Save.delete_save()
	check(not Save.has_save(), "no save after delete")
	var payload := {"save_version": Data.SAVE_VERSION, "game": Game.serialize(), "inventory": Inv.serialize(), "quests": Quests.serialize(), "world": {"test": 1}}
	check(Save.write_game(payload), "write save")
	check(Save.has_save(), "save exists")
	var back: Dictionary = Save.load_game()
	check(back["ok"] and int(back["data"]["world"]["test"]) == 1, "save round-trips")
	var f := FileAccess.open("user://save.json", FileAccess.WRITE)
	if f:
		f.store_string("{ this is not json")
		f.close()
	var rec: Dictionary = Save.load_game()
	check((rec["ok"] and rec["restored_backup"]) or (not rec["ok"] and String(rec["message"]) != ""), "corrupt save handled with backup or clear message")
	Save.delete_save()
	Game.reset_progress()
	Inv.clear()
	Quests.reset()
