extends Node
## Developer tool: starts a new game through Main, opens each UI panel and screenshots it.
const OUT := "/tmp/claude-0/-home-claude/d511e5eb-7ab3-5ffe-82b3-8179ffd27f6b/scratchpad/shots/"
func shot(n: String) -> void:
	for i in 6: await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + n + ".png")
	print("saved ", n)
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	var t0 := Time.get_ticks_msec()
	while not (main._current and main._current.has_signal("start_game")) and Time.get_ticks_msec() - t0 < 60000:
		await get_tree().process_frame
	main._current.start_game.emit(false)
	await get_tree().create_timer(0.5).timeout
	while Game.state != Game.State.PLAY and Time.get_ticks_msec() - t0 < 120000:
		await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	var s = main._session
	print("session: ", s)
	Game.reveal_area(0, 150, 90)
	Game.reveal_area(-60, 60, 50)
	Game.found_site("crash"); Game.found_site("outpost")
	Game.regions_seen["coast"] = true; Game.regions_seen["forest"] = true
	Game.read_log("log_crash"); Game.read_log("log_coast")
	Game.skill_points = 3
	for name in ["inventory", "craft", "quests", "skills", "map"]:
		s.open_panel(name)
		await get_tree().create_timer(0.3).timeout
		await shot("ui_" + name)
		s.panels[name].close()
		await get_tree().create_timer(0.2).timeout
	s.hud.log_requested.emit("log_coast")
	await shot("ui_log")
	s.panels["log"].close()
	s.hud.dialogue_requested.emit("survivor")
	await shot("ui_dialogue")
	s.panels["dialogue"].close()
	# death and respawn
	Inv.add("wood", 20)
	s.world.player.die("test")
	await get_tree().create_timer(2.6).timeout
	print("state after death: ", Game.state, " (DEFEAT=", Game.State.DEFEAT, ")")
	await shot("ui_defeat")
	s._respawn()
	await get_tree().create_timer(0.5).timeout
	print("after respawn state: ", Game.state, " dead=", s.world.player.dead, " health=", Game.health, " cache items=", Game.death_cache.get("items", []).size(), " node=", s.world.death_node != null)
	await shot("ui_respawn")
	get_tree().quit()
