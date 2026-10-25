extends SceneTree
const WG = preload("res://scripts/world/world_gen.gd")
const DW = preload("res://scripts/core/data_world.gd")
func _initialize() -> void:
	WG.setup(1337)
	var t0 := Time.get_ticks_msec()
	WG.build_grid()
	print("grid built in ms: ", Time.get_ticks_msec() - t0)
	var n: int = DW.GRID_N
	var img := Image.create(n + 1, n + 1, false, Image.FORMAT_RGB8)
	var hmin := 1e9
	var hmax := -1e9
	for i in WG.grid.size():
		hmin = minf(hmin, WG.grid[i]); hmax = maxf(hmax, WG.grid[i])
	print("height range ", hmin, " .. ", hmax)
	for iz in n + 1:
		for ix in n + 1:
			var x := -WG.half + ix * DW.CELL
			var z := -WG.half + iz * DW.CELL
			var h := WG.grid[iz * (n + 1) + ix]
			var w := WG.region_weights(x, z)
			var c := WG.terrain_color(x, z, h, WG.slope_at(x, z), w)
			var shade := 0.6 + 0.4 * clampf(WG.normal_at(x, z).dot(Vector3(-0.5, 0.8, -0.3).normalized()), 0.0, 1.0)
			c = Color(c.r * shade, c.g * shade, c.b * shade)
			if h < 0.0:
				c = Color(0.1, 0.3 + h * 0.01, 0.55 + h * 0.02).lerp(c, 0.25)
			if c.a > 0: pass
			img.set_pixel(ix, iz, c)
	for id in DW.SITES:
		var p: Vector2 = DW.SITES[id]["pos"]
		var px := int((p.x + WG.half) / DW.CELL)
		var pz := int((p.y + WG.half) / DW.CELL)
		for dx in range(-2, 3):
			for dz in range(-2, 3):
				if px + dx >= 0 and px + dx <= n and pz + dz >= 0 and pz + dz <= n:
					img.set_pixel(px + dx, pz + dz, Color(1, 0, 1))
	img.resize(768, 768, Image.INTERPOLATE_NEAREST)
	img.save_png("/tmp/claude-0/-home-claude/d511e5eb-7ab3-5ffe-82b3-8179ffd27f6b/scratchpad/heightmap.png")
	quit()
