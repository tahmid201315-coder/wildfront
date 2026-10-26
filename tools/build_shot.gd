extends Node
const World = preload("res://scripts/world/world.gd")
const OUT := "/tmp/claude-0/-home-claude/d511e5eb-7ab3-5ffe-82b3-8179ffd27f6b/scratchpad/shots/"
func _ready() -> void:
	var w = World.new()
	add_child(w)
	w.build(false)
	await w.loaded
	Game.state = Game.State.PLAY
	var bm = w.builder
	var p = w.player
	var WG = preload("res://scripts/world/world_gen.gd")
	var base := Vector3(0, 0, 160)
	for cx in [-1, 0]:
		var c: Vector2 = bm.cell_center(Vector2i(cx, 40))
		var top: float = 0.0
		for ix in 3:
			for iz in 3:
				top = maxf(top, WG.height_at(c.x + (ix - 1) * 2.0, c.y + (iz - 1) * 2.0))
		var f = bm.place("foundation", Vector3(c.x, top, c.y), 0.0)
		f.cell = Vector2i(cx, 40)
		bm.cells[bm.ckey(f.cell)] = {"found": f}
	var t: float = bm.foundation_top(Vector2i(-1, 40))
	for k in ["h,-1,40", "h,0,40", "v,-1,40", "v,1,40", "h,-1,41"]:
		var ep: Dictionary = bm.edge_pos(k)
		var s = bm.place("wall", Vector3(ep["pos"].x, t, ep["pos"].y), ep["yaw"])
		bm.edges[k] = s
	var ep2: Dictionary = bm.edge_pos("h,0,41")
	bm.place("door", Vector3(ep2["pos"].x, t, ep2["pos"].y), 0.0)
	var r = bm.place("roof", Vector3(-2, t + 3.0, 162), 0.0)
	bm.place("campfire", Vector3(5.5, WG.height_at(5.5, 164), 164), 0.0)
	bm.place("workbench", Vector3(8.5, WG.height_at(8.5, 164), 163), 0.4)
	bm.place("cooking", Vector3(8.5, WG.height_at(8.5, 167), 167), -0.3)
	bm.place("chest", Vector3(5, WG.height_at(5, 168), 168), 0.2)
	bm.place("lamp", Vector3(11, WG.height_at(11, 165), 165), 0.0)
	bm.place("turret", Vector3(11, WG.height_at(11, 169), 169), 0.0)
	bm.place("barricade", Vector3(3, WG.height_at(3, 171), 171), 0.0)
	bm.place("processor", Vector3(14, WG.height_at(14, 166), 166), 0.0)
	bm.place("bedroll", Vector3(-2, t + 0.1, 162), 0.0)
	bm.place("shelter", Vector3(-8, WG.height_at(-8, 166), 166), 0.0)
	p.place_at(Vector3(4, WG.height_at(4, 150) + 0.5, 152))
	p.cam_yaw = PI
	p.cam_pitch = -0.3
	p.cam_dist = 9.0
	p._cam_dist_now = 9.0
	Game.time_of_day = 0.42
	for i in 30: await get_tree().physics_frame
	for i in 6: await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + "base.png")
	Game.time_of_day = 0.80
	p.cam_yaw = PI + 0.5
	for i in 30: await get_tree().physics_frame
	for i in 6: await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + "base_night.png")
	print("done")
	get_tree().quit()
