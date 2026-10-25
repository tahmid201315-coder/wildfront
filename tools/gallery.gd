extends Node3D
## Developer tool: lays all procedural models out in a row for visual inspection.
const Models = preload("res://scripts/gfx/models.gd")
const SkyEnv = preload("res://scripts/world/sky_env.gd")
const OUT := "/tmp/claude-0/-home-claude/d511e5eb-7ab3-5ffe-82b3-8179ffd27f6b/scratchpad/shots/"
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var sky := SkyEnv.new(); add_child(sky); sky.setup(); sky.time_of_day = 0.4; sky.apply_time(0.0)
	sky.env.fog_density = 0.0005
	var ground := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(200, 80)
	var gm := StandardMaterial3D.new(); gm.albedo_color = Color(0.3, 0.42, 0.22); pm.material = gm; ground.mesh = pm; add_child(ground)
	var groups := [["palm","broadleaf","pine","dead_tree","burnt_tree","bush"], ["fern","grass","mushroom","mushroom_giant","flower","reed"], ["rock","rock_big","rock_dark","rock_ash","iron_ore","copper_ore"], ["coal_rock","crystal","crystal_red","log","stump","vent","wreck_part","shell"]]
	var row := 0
	for g in groups:
		var x := -26.0 + 0.0
		for k in g:
			for v in 2:
				var mi := MeshInstance3D.new(); mi.mesh = Models.get_mesh(k, v); mi.position = Vector3(x, 0, row * 11.0 - 16.0); add_child(mi)
				x += 4.5
		row += 1
	var cam := Camera3D.new(); cam.far = 400; cam.fov = 55; add_child(cam)
	var shots := {"g1": [Vector3(-8, 8, -26), Vector3(-8, 3, -16)], "g2": [Vector3(-8, 6, -12), Vector3(-8, 1, -5)], "g3": [Vector3(-8, 6, 2), Vector3(-8, 1, 6)], "g4": [Vector3(-6, 6, 12), Vector3(-6, 1, 17)]}
	for k in shots:
		cam.global_position = shots[k][0]; cam.look_at(shots[k][1])
		for i in 4: await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OUT + k + ".png")
	get_tree().quit()
