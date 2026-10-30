extends Node
## Regression: a boss (or anything else) from a previous room must never survive into the next room, e.g. Daily Trial -> Save and Quit -> Continue.
var passed := 0
var failed := 0
func check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		passed += 1
		print("  ok   ", name)
	else:
		failed += 1
		print("  FAIL ", name, "  ", detail)
func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
func bosses_in_tree(root: Node) -> int:
	var n := 0
	for c in root.find_children("*", "Node", true, false):
		if c is Boss:
			n += 1
	return n
func _ready() -> void:
	Save.base_dir = "user://test_leak/"
	DirAccess.make_dir_recursive_absolute("user://test_leak/")
	for s in 3:
		Save.delete_slot(s)
	var m: Node = load("res://scenes/main.tscn").instantiate()
	add_child(m)
	await frames(3)
	# a normal story save exists
	m._on_new_game(0, 1)
	m.cutscene.skip()
	await frames(10)
	m.stage.autosave()
	# daily trial, wake the boss, then Save and Quit
	m._on_quit_to_title()
	await frames(3)
	m._on_daily()
	await frames(5)
	check("trial has exactly one boss", bosses_in_tree(m.stage) == 1, str(bosses_in_tree(m.stage)))
	m.stage.player.position.x = 12.0 * Level.T
	await frames(120)
	check("boss woke up in the trial", m.stage.boss != null and m.stage.boss.state in ["intro", "fight"], str(m.stage.boss.state if m.stage.boss else "none"))
	m._on_quit_to_title()
	await frames(5)
	check("quit from trial leaves the story save untouched", Save.slot_exists(0) and Save.load_slot(0)["data"]["game"]["fragments"] == 0 and not Game.trial)
	m._on_continue(0)
	await frames(10)
	check("Continue shows no boss at all", bosses_in_tree(m.stage) == 0 and m.stage.boss == null, str(bosses_in_tree(m.stage)))
	check("no boss bar, no boss-fight flag, normal room music", not Game.in_boss_fight and m.stage.room_id == "meadows_1", m.stage.room_id)
	# New Game after a trial
	m._on_daily()
	await frames(5)
	m._on_quit_to_title()
	await frames(3)
	m._on_new_game(1, 1)
	m.cutscene.skip()
	await frames(10)
	check("New Game after a trial has no boss and no trial flag", bosses_in_tree(m.stage) == 0 and not Game.trial and Game.fragments == 0)
	# walking out of a boss arena into another room
	Game.new_progress()
	for a in Game.ABILITY_NAMES:
		Game.unlock_ability(a)
	m.stage.change_room("meadows_boss", "start")
	await frames(3)
	check("boss arena has a boss", bosses_in_tree(m.stage) == 1)
	m.stage.change_room("meadows_6", "from_next")
	await frames(3)
	check("leaving the arena removes the boss body", bosses_in_tree(m.stage) == 0, str(bosses_in_tree(m.stage)))
	# nothing else leaks: count nodes after many room changes
	m.stage.change_room("ember_2", "start")
	await frames(3)
	var base: int = m.stage.entities.get_child_count()
	for i in 6:
		m.stage.change_room("ember_2", "start")
		await frames(2)
		m.stage.change_room("meadows_boss", "start")
		await frames(2)
	m.stage.change_room("ember_2", "start")
	await frames(3)
	check("room changes do not accumulate entity nodes (%d vs %d)" % [m.stage.entities.get_child_count(), base], m.stage.entities.get_child_count() <= base + 1)
	for s in 3:
		Save.delete_slot(s)
	print("\n== %d passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)
