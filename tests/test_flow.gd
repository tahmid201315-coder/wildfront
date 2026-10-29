extends Node
## End-to-end game flow through the real Main scene: title, new game, cutscene skip, play, pause, settings, death, retry,
## save/continue, difficulty, touch controls, boss defeat -> reveal cutscene, ending and victory screen.
var passed := 0
var failed := 0
var m: Node

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

func _ready() -> void:
	Save.base_dir = "user://test_flow/"
	DirAccess.make_dir_recursive_absolute("user://test_flow/")
	for s in 3:
		Save.delete_slot(s)
	m = load("res://scenes/main.tscn").instantiate()
	add_child(m)
	await frames(5)
	check("boots to title", Game.state == Game.State.TITLE and m.menus.current == "title", m.menus.current)
	m.menus.show_slots(true)
	await frames(2)
	check("slot screen lists 3 slots", m.menus.current == "slots")
	m.menus.show_difficulty(1)
	check("difficulty screen", m.menus.current == "difficulty")
	m._on_new_game(1, 2)
	await frames(3)
	check("intro cutscene plays", m.cutscene.active and Game.state == Game.State.CUTSCENE)
	check("save file created on new game", Save.slot_exists(1))
	m.cutscene.advance()   # finish typing
	m.cutscene.advance()   # next line
	check("cutscene advances", m.cutscene.li == 1)
	m.cutscene.skip()
	await frames(10)
	check("skip starts play", Game.state == Game.State.PLAY and m.stage.data != null and m.stage.data.id == "meadows_1", str(Game.state))
	check("veteran difficulty applied", Game.settings["difficulty"] == 2 and Game.difficulty()["name"] == "Veteran")
	# pause
	var ev := InputEventAction.new()
	ev.action = "pause"
	ev.pressed = true
	m._unhandled_input(ev)
	await frames(2)
	check("pause opens and freezes", Game.state == Game.State.PAUSE and m.menus.current == "pause" and get_tree().paused)
	m.menus.open_screen(m.menus.show_settings)
	check("settings screen", m.menus.current == "settings")
	Game.apply_setting("music", 0.3)
	check("music volume applies", absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")) - linear_to_db(0.3)) < 0.01)
	m.menus.back()
	check("back returns to pause", m.menus.current == "pause")
	for fn in [m.menus.show_map, m.menus.show_inventory, m.menus.show_skills, m.menus.show_quests, m.menus.show_journal]:
		m.menus.open_screen(fn)
		m.menus.back()
	check("every sub screen opens", m.menus.screen_log.has("map") and m.menus.screen_log.has("inventory") and m.menus.screen_log.has("skills") and m.menus.screen_log.has("quests") and m.menus.screen_log.has("journal"))
	m.menus.back()   # last back from pause root resumes
	await frames(2)
	check("resume returns to play", Game.state == Game.State.PLAY and not get_tree().paused, str(Game.state))
	# remap
	Menus.set_key("jump", KEY_G)
	var has_g := false
	for e in InputMap.action_get_events("jump"):
		if e is InputEventKey and e.physical_keycode == KEY_G:
			has_g = true
	check("key remap works", has_g and Game.settings["keys"]["jump"] == KEY_G)
	Menus.reset_keys()
	# death -> game over -> retry
	m.stage.player.invuln_t = 0.0
	m.stage.player.hurt(9999.0, m.stage.player.position.x + 10.0, 1.0)
	await frames(5)
	check("player dies", not m.stage.player.alive or Game.hp <= 0.0)
	await frames(120)
	check("game over shown after death", m.menus.current == "gameover" and Game.state == Game.State.GAMEOVER, "%s %d" % [m.menus.current, Game.state])
	m._on_retry()
	m.menus.close_all()
	await frames(5)
	check("retry respawns", m.stage.player.alive and Game.hp > 0.0 and Game.state == Game.State.PLAY)
	check("death counted", Game.deaths == 1)
	# save and continue
	Game.shards = 321
	m.stage.autosave()
	m._on_quit_to_title()
	await frames(3)
	check("quit to title", Game.state == Game.State.TITLE and m.menus.current == "title")
	Game.new_progress()
	m._on_continue(1)
	await frames(5)
	check("continue restores progress", Game.shards == 321 and Game.state == Game.State.PLAY, "%d" % Game.shards)
	# corrupt save does not crash and leaves title usable
	var f := FileAccess.open(Save.path(2, "json"), FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	m._on_quit_to_title()
	await frames(2)
	m._on_continue(2)
	await frames(3)
	check("corrupt save handled", Game.state == Game.State.TITLE)
	# touch controls inject actions
	m._on_continue(1)
	await frames(3)
	m.touch.set_forced(true)
	m.touch._press("jump")
	Input.flush_buffered_events()
	await frames(4)
	check("touch button presses action", Input.is_action_pressed("jump"))
	m.touch._release("jump")
	Input.flush_buffered_events()
	await frames(4)
	check("touch button releases action", not Input.is_action_pressed("jump"))
	m.touch.release_all()
	# ending flow
	m._on_boss_defeated("eclipse_architect")
	await get_tree().create_timer(2.8, true).timeout
	check("finale cutscene after final boss", m.cutscene.active and m.cutscene.id == "finale", m.cutscene.id)
	m.cutscene.skip()
	await frames(2)
	check("ending follows finale", m.cutscene.active and m.cutscene.id == "ending")
	m.cutscene.skip()
	await frames(3)
	check("victory screen + completed flag", m.menus.current == "victory" and Game.completed)
	m.menus.show_credits_end()
	check("credits screen", m.menus.current == "credits_scene")
	for s in 3:
		Save.delete_slot(s)
	print("\n== %d passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)
