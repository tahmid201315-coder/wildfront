extends Node
## Developer tool: builds the real world and screenshots from the player camera.
## args: name:x,z,yaw,pitch,time,dist[,state[,held]] ...
const World = preload("res://scripts/world/world.gd")
const OUT := "/tmp/claude-0/-home-claude/d511e5eb-7ab3-5ffe-82b3-8179ffd27f6b/scratchpad/shots/"
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var w = World.new()
	add_child(w)
	w.build(false)
	await w.loaded
	Game.state = Game.State.PLAY
	w.weather.kind = "rain"; w.weather.intensity = 1.0; w.weather._timer = 9999.0
	var p = w.player
	for a in OS.get_cmdline_user_args():
		var parts: PackedStringArray = a.split(":")
		var v: PackedStringArray = parts[1].split(",")
		var x := float(v[0]); var z := float(v[1])
		p.place_at(Vector3(x, WG_h(x, z) + 0.5, z))
		p.cam_yaw = float(v[2]); p.cam_pitch = float(v[3])
		Game.time_of_day = float(v[4])
		p.cam_dist = float(v[5])
		p._cam_dist_now = p.cam_dist
		p.facing_yaw = p.cam_yaw
		if v.size() > 6:
			p.model.state = v[6]
			p.model.action_kind = v[7] if v.size() > 7 else ""
			p.model.action_len = 1.0
			p.model.phase_t = float(v[8]) if v.size() > 8 else 0.0
		for i in 40:
			await get_tree().physics_frame
			if v.size() > 6:
				p.model.state = v[6]
		for i in 6: await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OUT + parts[0] + ".png")
		print("saved ", parts[0], " at ", p.global_position)
	get_tree().quit()
func WG_h(x, z): return preload("res://scripts/world/world_gen.gd").height_at(x, z)
