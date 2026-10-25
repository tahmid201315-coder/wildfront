extends Node
const World = preload("res://scripts/world/world.gd")
func _ready():
	var t0 := Time.get_ticks_msec()
	var w = World.new()
	add_child(w)
	w.loading_progress.connect(func(f, s): print("  %.2f %s (%d ms)" % [f, s, Time.get_ticks_msec() - t0]))
	Game.new_game_state() if Game.has_method("new_game_state") else null
	w.build(false)
	await w.loaded
	print("resources: ", w.resources.size(), " decor chunks: ", w.decor.built.size())
	var p = w.player
	print("player at ", p.global_position)
	Game.state = Game.State.PLAY
	for i in 120:
		await get_tree().physics_frame
	print("after 120 frames: ", p.global_position, " grounded=", p.is_on_floor())
	get_tree().quit()
