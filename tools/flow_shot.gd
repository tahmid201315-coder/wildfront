extends Node
## Developer tool: drives the real Main scene (boot -> menu -> new game) and screenshots each stage.
const OUT := "/tmp/claude-0/-home-claude/d511e5eb-7ab3-5ffe-82b3-8179ffd27f6b/scratchpad/shots/"
func shot(n: String) -> void:
	for i in 5: await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + n + ".png")
	print("saved ", n)
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(1.0).timeout
	await shot("f_boot")
	var t0 := Time.get_ticks_msec()
	while not (main._current and main._current.has_signal("start_game")) and Time.get_ticks_msec() - t0 < 60000:
		await get_tree().process_frame
	print("menu after ", Time.get_ticks_msec() - t0, " ms")
	await shot("f_menu")
	main._current.start_game.emit(false)
	await get_tree().create_timer(1.0).timeout
	await shot("f_loading")
	t0 = Time.get_ticks_msec()
	while Game.state != Game.State.PLAY and Time.get_ticks_msec() - t0 < 90000:
		await get_tree().process_frame
	print("playing after ", Time.get_ticks_msec() - t0, " ms state=", Game.state)
	await get_tree().create_timer(1.5).timeout
	await shot("f_hud")
	get_tree().quit()
