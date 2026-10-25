extends Node3D
## Developer tool: builds terrain/water/sky, positions a camera, saves screenshots.
## xvfb-run godot --path . --rendering-driver opengl3 res://tools/viewer.tscn -- <name>:x,y,z,lookx,looky,lookz,time ...
const WG = preload("res://scripts/world/world_gen.gd")
const Terrain = preload("res://scripts/world/terrain.gd")
const SkyEnv = preload("res://scripts/world/sky_env.gd")
const OUT := "/tmp/claude-0/-home-claude/d511e5eb-7ab3-5ffe-82b3-8179ffd27f6b/scratchpad/shots/"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	WG.setup(1337)
	WG.build_grid()
	WG.build_vertex_data()
	var terrain := Terrain.new()
	add_child(terrain)
	terrain.build_all_blocking()
	terrain.build_water()
	var sky := SkyEnv.new()
	add_child(sky)
	sky.setup()
	var cam := Camera3D.new()
	cam.far = 700.0
	cam.fov = 70.0
	add_child(cam)
	var shots: Array = []
	for a in OS.get_cmdline_user_args():
		shots.append(a)
	for s in shots:
		var parts: PackedStringArray = s.split(":")
		var v: PackedStringArray = parts[1].split(",")
		var p := Vector3(float(v[0]), float(v[1]), float(v[2]))
		var l := Vector3(float(v[3]), float(v[4]), float(v[5]))
		sky.time_of_day = float(v[6])
		sky.apply_time(0.0)
		cam.global_position = p
		cam.look_at(l)
		for i in 4: await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OUT + parts[0] + ".png")
		print("saved ", parts[0])
	get_tree().quit()
