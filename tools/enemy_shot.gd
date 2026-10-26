extends Node
const World = preload("res://scripts/world/world.gd")
const EM = preload("res://scripts/gfx/enemy_models.gd")
const OUT := "/tmp/claude-0/-home-claude/d511e5eb-7ab3-5ffe-82b3-8179ffd27f6b/scratchpad/shots/"
func _ready() -> void:
	var w = World.new()
	add_child(w)
	w.build(false)
	await w.loaded
	Game.state = Game.State.PLAY
	var WG = preload("res://scripts/world/world_gen.gd")
	var p = w.player
	var groups := [["e1", ["stalker", "brute", "wraith", "sentinel"], 4.5], ["e2", ["grove_guardian", "furnace_colossus", "core_architect"], 11.0], ["e3", ["crab", "mossdeer", "ridge_goat", "ember_newt"], 3.0]]
	for g in groups:
		var spacing: float = g[2]
		var names: Array = g[1]
		var nodes := []
		for i in names.size():
			var x := -spacing * (names.size() - 1) * 0.5 + i * spacing
			var m: Node3D = EM.build(names[i])
			w.add_child(m)
			m.global_position = Vector3(x, WG.height_at(x, 150) , 150)
			m.rotation.y = 0.0
			nodes.append(m)
		p.place_at(Vector3(0, WG.height_at(0, 140) + 1, 140 + (22 if spacing > 10 else 0)))
		p.global_position.z = 150 - spacing * 1.6 - (6 if spacing < 10 else 0)
		p.cam_yaw = PI
		p.cam_pitch = -0.1
		p.cam_dist = 4.0
		Game.time_of_day = 0.45
		for i in 30: await get_tree().physics_frame
		p.model.visible = false
		var cam: Camera3D = p.cam
		cam.global_position = Vector3(0, WG.height_at(0, 150) + 2.2 + spacing * 0.25, 150 - spacing * (names.size() * 0.35 + 0.9))
		cam.look_at(Vector3(0, WG.height_at(0, 150) + 1.6 + spacing * 0.12, 150))
		p.set_physics_process(false)
		for i in 6: await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OUT + g[0] + ".png")
		for n in nodes: n.queue_free()
		p.set_physics_process(true)
	print("done")
	get_tree().quit()
