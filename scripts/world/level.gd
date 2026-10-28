class_name Level
extends Node2D
## A room: tile grid, collision queries for actors, chunked tile rendering and liquid animation.
## Coordinates are pixels; tile (tx, ty) covers [tx*32, (tx+1)*32).

const T := 32
const CHUNK := 16

var data: LevelData
var w: int = 0
var h: int = 0
var cells: PackedByteArray = PackedByteArray()
var theme: Dictionary = {}
var region_id: String = "meadows"
var atlas: Dictionary = {}
var solids: Array = []                 # dynamic solid bodies: need solid_rect() and top_only
var _chunks: Dictionary = {}           # Vector2i -> ImageTexture
var _dirty: Dictionary = {}
var _time: float = 0.0
var lens_reveal: bool = false
var liquid: Node2D
var wind_gust: float = 0.0
var stage: Stage = null


func setup(d: LevelData) -> void:
	data = d
	w = d.w
	h = d.h
	region_id = d.region
	theme = Defs.REGIONS[region_id]
	cells.resize(w * h)
	for y in h:
		for x in w:
			var c: String = d.rows[y][x]
			cells[y * w + x] = int(Tiles.CHAR_TO_TILE.get(c, Tiles.AIR))
	atlas = Tiles.build_atlas(theme, region_id)
	liquid = _LiquidLayer.new()
	liquid.level = self
	liquid.z_index = 8
	add_child(liquid)
	for cy in range((h + CHUNK - 1) / CHUNK):
		for cx in range((w + CHUNK - 1) / CHUNK):
			_dirty[Vector2i(cx, cy)] = true


func pixel_size() -> Vector2:
	return Vector2(w * T, h * T)


func tile(tx: int, ty: int) -> int:
	if tx < 0 or tx >= w:
		return Tiles.SOLID
	if ty < 0:
		return Tiles.AIR
	if ty >= h:
		return Tiles.AIR
	return cells[ty * w + tx]


func tile_at_px(p: Vector2) -> int:
	return tile(int(floor(p.x / T)), int(floor(p.y / T)))


func set_tile(tx: int, ty: int, id: int) -> void:
	if tx < 0 or tx >= w or ty < 0 or ty >= h:
		return
	cells[ty * w + tx] = id
	_dirty[Vector2i(tx / CHUNK, ty / CHUNK)] = true
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = tx + d.x
		var ny: int = ty + d.y
		if nx >= 0 and ny >= 0 and nx < w and ny < h:
			_dirty[Vector2i(nx / CHUNK, ny / CHUNK)] = true
	queue_redraw()


# ------------------------------------------------------------------ collision
func _tile_range(r: Rect2) -> Rect2i:
	var x0 := int(floor(r.position.x / T))
	var x1 := int(floor((r.end.x - 0.001) / T))
	var y0 := int(floor(r.position.y / T))
	var y1 := int(floor((r.end.y - 0.001) / T))
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)


func rect_hits_solid(r: Rect2) -> bool:
	var tr := _tile_range(r)
	for ty in range(tr.position.y, tr.end.y):
		for tx in range(tr.position.x, tr.end.x):
			if Tiles.is_solid(tile(tx, ty)):
				return true
	for s in solids:
		if is_instance_valid(s) and not s.top_only and s.solid_rect().intersects(r):
			return true
	return false


## Moves a body. `r` is the current rect, `vel` pixels/second. Returns:
## {rect, vel, floor: bool, floor_tile: int, floor_obj: Node, wall: int (-1 left, 1 right, 0), ceil: bool}
func move_body(r: Rect2, vel: Vector2, dt: float, drop: bool = false, solid_objects: bool = true) -> Dictionary:
	var res := {"rect": r, "vel": vel, "floor": false, "floor_tile": 0, "floor_obj": null, "wall": 0, "ceil": false}
	var dx := vel.x * dt
	var dy := vel.y * dt
	# ---- X
	if dx != 0.0:
		r.position.x += dx
		var tr := _tile_range(r)
		if dx > 0.0:
			var best := INF
			for ty in range(tr.position.y, tr.end.y):
				for tx in range(tr.position.x, tr.end.x):
					if Tiles.is_solid(tile(tx, ty)):
						best = minf(best, float(tx * T))
			if solid_objects:
				for s in solids:
					if is_instance_valid(s) and not s.top_only:
						var sr: Rect2 = s.solid_rect()
						if sr.intersects(r) and r.end.y > sr.position.y + 2.0:
							best = minf(best, sr.position.x)
			if best < INF:
				r.position.x = best - r.size.x
				res["wall"] = 1
				vel.x = 0.0
		else:
			var best2 := -INF
			for ty in range(tr.position.y, tr.end.y):
				for tx in range(tr.position.x, tr.end.x):
					if Tiles.is_solid(tile(tx, ty)):
						best2 = maxf(best2, float((tx + 1) * T))
			if solid_objects:
				for s in solids:
					if is_instance_valid(s) and not s.top_only:
						var sr2: Rect2 = s.solid_rect()
						if sr2.intersects(r) and r.end.y > sr2.position.y + 2.0:
							best2 = maxf(best2, sr2.end.x)
			if best2 > -INF:
				r.position.x = best2
				res["wall"] = -1
				vel.x = 0.0
	# ---- Y
	var prev_bottom := r.end.y
	if dy != 0.0:
		r.position.y += dy
		var tr2 := _tile_range(r)
		if dy > 0.0:
			var land := INF
			for ty in range(tr2.position.y, tr2.end.y):
				for tx in range(tr2.position.x, tr2.end.x):
					var t := tile(tx, ty)
					var top := float(ty * T)
					if Tiles.is_solid(t):
						land = minf(land, top)
					elif t == Tiles.ONEWAY and not drop and prev_bottom <= top + 1.0:
						land = minf(land, top)
			if solid_objects:
				for s in solids:
					if is_instance_valid(s):
						var sr3: Rect2 = s.solid_rect()
						if sr3.intersects(r) and prev_bottom <= sr3.position.y + 6.0 and not (drop and s.top_only):
							land = minf(land, sr3.position.y)
			if land < INF:
				r.position.y = land - r.size.y
				vel.y = 0.0
		else:
			var ceil_y := -INF
			for ty in range(tr2.position.y, tr2.end.y):
				for tx in range(tr2.position.x, tr2.end.x):
					if Tiles.is_solid(tile(tx, ty)):
						ceil_y = maxf(ceil_y, float((ty + 1) * T))
			if solid_objects:
				for s in solids:
					if is_instance_valid(s) and not s.top_only:
						var sr4: Rect2 = s.solid_rect()
						if sr4.intersects(r):
							ceil_y = maxf(ceil_y, sr4.end.y)
			if ceil_y > -INF:
				r.position.y = ceil_y
				vel.y = 0.0
				res["ceil"] = true
	# ---- floor probe
	var probe := Rect2(r.position.x + 1.0, r.end.y, r.size.x - 2.0, 1.5)
	var tr3 := _tile_range(probe)
	for ty in range(tr3.position.y, tr3.end.y):
		for tx in range(tr3.position.x, tr3.end.x):
			var t2 := tile(tx, ty)
			if Tiles.is_solid(t2) or (t2 == Tiles.ONEWAY and not drop and r.end.y <= float(ty * T) + 1.5 and vel.y >= 0.0):
				res["floor"] = true
				res["floor_tile"] = t2
	if solid_objects:
		for s in solids:
			if is_instance_valid(s):
				var sr5: Rect2 = s.solid_rect()
				if sr5.intersects(probe) and r.end.y <= sr5.position.y + 3.0 and vel.y >= 0.0:
					res["floor"] = true
					res["floor_obj"] = s
					if res["floor_tile"] == 0:
						res["floor_tile"] = Tiles.SOLID
	res["rect"] = r
	res["vel"] = vel
	return res


func wall_probe(r: Rect2, dir: int) -> bool:
	var p := Rect2(r.position.x + (r.size.x if dir > 0 else -2.0), r.position.y + 6.0, 2.0, r.size.y - 12.0)
	return rect_hits_solid(p)


## Strongest hazard overlapping a (slightly shrunk) rect: {damage, tile} or empty.
func hazard_in(r: Rect2) -> Dictionary:
	var s := r.grow(-5.0)
	var tr := _tile_range(s)
	var best := {}
	for ty in range(tr.position.y, tr.end.y):
		for tx in range(tr.position.x, tr.end.x):
			var t := tile(tx, ty)
			if Tiles.is_hazard(t):
				# spikes and thorns only hurt in their lower 60%; lava over the whole tile
				var tile_r := Rect2(tx * T, ty * T + (12 if t != Tiles.LAVA else 4), T, T - (12 if t != Tiles.LAVA else 4))
				if tile_r.intersects(s):
					var dmg := Tiles.hazard_damage(t)
					if best.is_empty() or dmg > float(best["damage"]):
						best = {"damage": dmg, "tile": t, "pos": Vector2(tx * T + 16, ty * T + 16)}
	return best


func in_water(r: Rect2) -> bool:
	var c := Vector2(r.get_center().x, r.position.y + r.size.y * 0.4)
	return tile_at_px(c) == Tiles.WATER


func ladder_at(r: Rect2) -> bool:
	var c := r.get_center()
	return tile_at_px(Vector2(c.x, c.y)) == Tiles.LADDER or tile_at_px(Vector2(c.x, r.end.y - 4.0)) == Tiles.LADDER


func ladder_column_x(r: Rect2) -> float:
	return floor(r.get_center().x / T) * T + T * 0.5


func ground_below(p: Vector2, max_px: float = 600.0) -> float:
	## y of the first solid/oneway surface below p (or -1)
	var tx := int(floor(p.x / T))
	var ty := int(floor(p.y / T))
	var n := int(max_px / T) + 1
	for i in n:
		var t := tile(tx, ty + i)
		if Tiles.is_solid(t) or t == Tiles.ONEWAY:
			return float((ty + i) * T)
	return -1.0


# ------------------------------------------------------------------ rendering
var _last_view: Rect2i = Rect2i()


func _process(delta: float) -> void:
	_time += delta
	liquid.queue_redraw()
	var vr := _visible_rect().grow(8.0)
	var key := Rect2i(int(floor(vr.position.x / (CHUNK * T))), int(floor(vr.position.y / (CHUNK * T))), int(floor(vr.end.x / (CHUNK * T))), int(floor(vr.end.y / (CHUNK * T))))
	if key != _last_view or lens_reveal:
		_last_view = key
		queue_redraw()


func _visible_rect() -> Rect2:
	var inv := get_canvas_transform().affine_inverse()
	var vp := get_viewport_rect()
	return Rect2(inv * vp.position, vp.size * inv.get_scale())


func _draw() -> void:
	var vr := _visible_rect().grow(8.0)
	var cx0 := maxi(int(floor(vr.position.x / (CHUNK * T))), 0)
	var cx1 := mini(int(floor(vr.end.x / (CHUNK * T))), (w - 1) / CHUNK)
	var cy0 := maxi(int(floor(vr.position.y / (CHUNK * T))), 0)
	var cy1 := mini(int(floor(vr.end.y / (CHUNK * T))), (h - 1) / CHUNK)
	for cy in range(cy0, cy1 + 1):
		for cx in range(cx0, cx1 + 1):
			var key := Vector2i(cx, cy)
			if _dirty.has(key) or not _chunks.has(key):
				_chunks[key] = _render_chunk(cx, cy)
				_dirty.erase(key)
			draw_texture(_chunks[key], Vector2(cx * CHUNK * T, cy * CHUNK * T))
	if lens_reveal:
		for ty in range(maxi(int(vr.position.y / T), 0), mini(int(vr.end.y / T) + 1, h)):
			for tx in range(maxi(int(vr.position.x / T), 0), mini(int(vr.end.x / T) + 1, w)):
				if cells[ty * w + tx] == Tiles.BREAK:
					var pulse := 0.5 + 0.5 * sin(_time * 3.0 + tx)
					draw_rect(Rect2(tx * T + 2, ty * T + 2, T - 4, T - 4), Color(theme["glow"].r, theme["glow"].g, theme["glow"].b, 0.25 + 0.25 * pulse), false, 2.0)


func _render_chunk(cx: int, cy: int) -> ImageTexture:
	var img := Image.create(CHUNK * T, CHUNK * T, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for ly in CHUNK:
		for lx in CHUNK:
			var tx := cx * CHUNK + lx
			var ty := cy * CHUNK + ly
			if tx >= w or ty >= h:
				continue
			var t: int = cells[ty * w + tx]
			if t == Tiles.AIR or t == Tiles.WATER or t == Tiles.LAVA:
				continue
			var variants: Array = atlas.get(t, [])
			if variants.is_empty():
				continue
			var v := int(Tiles._h(tx, ty, 77) * variants.size()) % variants.size()
			var src: Image = variants[v]
			var dst := Vector2i(lx * T, ly * T)
			if t == Tiles.ONEWAY or t == Tiles.SPIKE or t == Tiles.THORN or t == Tiles.LADDER:
				img.blend_rect(src, Rect2i(0, 0, T, T), dst)
			else:
				img.blit_rect(src, Rect2i(0, 0, T, T), dst)
			if t == Tiles.SOLID or t == Tiles.BRICK or t == Tiles.ICE:
				if not Tiles.is_solid(tile(tx, ty - 1)) and tile(tx, ty - 1) != Tiles.ONEWAY:
					var cap: Image = atlas["cap"][int(Tiles._h(tx, ty, 5) * 4.0) % 4]
					img.blend_rect(cap, Rect2i(0, 0, T, T), dst)
				# soft shading on exposed lower and side edges
				if not Tiles.is_solid(tile(tx, ty + 1)):
					for i in T:
						for k in 3:
							var px := dst + Vector2i(i, T - 1 - k)
							var c := img.get_pixelv(px)
							img.set_pixelv(px, c.darkened(0.35 - 0.1 * k))
				if not Tiles.is_solid(tile(tx - 1, ty)):
					for i in T:
						var px2 := dst + Vector2i(0, i)
						img.set_pixelv(px2, img.get_pixelv(px2).lightened(0.18))
				if not Tiles.is_solid(tile(tx + 1, ty)):
					for i in T:
						var px3 := dst + Vector2i(T - 1, i)
						img.set_pixelv(px3, img.get_pixelv(px3).darkened(0.25))
	return ImageTexture.create_from_image(img)


class _LiquidLayer extends Node2D:
	var level: Level

	func _draw() -> void:
		var l := level
		var vr := l._visible_rect().grow(8.0)
		var t := l._time
		for ty in range(maxi(int(vr.position.y / Level.T), 0), mini(int(vr.end.y / Level.T) + 1, l.h)):
			for tx in range(maxi(int(vr.position.x / Level.T), 0), mini(int(vr.end.x / Level.T) + 1, l.w)):
				var c: int = l.cells[ty * l.w + tx]
				if c != Tiles.WATER and c != Tiles.LAVA:
					continue
				var top_open: bool = l.tile(tx, ty - 1) != c
				var x0 := float(tx * Level.T)
				var y0 := float(ty * Level.T)
				if c == Tiles.WATER:
					var col := Color(0.15, 0.45, 0.8, 0.42)
					draw_rect(Rect2(x0, y0 + (6 if top_open else 0), Level.T, Level.T - (6 if top_open else 0)), col)
					if top_open:
						var pts := PackedVector2Array()
						for i in 9:
							pts.append(Vector2(x0 + i * 4, y0 + 5 + sin(t * 2.5 + (x0 + i * 4) * 0.08) * 2.0))
						draw_polyline(pts, Color(0.75, 0.95, 1.0, 0.85), 2.0)
				else:
					var base := Color(1.0, 0.35, 0.08, 0.95)
					var shade := 0.5 + 0.5 * sin(t * 2.0 + float(tx) * 0.6 + float(ty))
					draw_rect(Rect2(x0, y0 + (4 if top_open else 0), Level.T, Level.T - (4 if top_open else 0)), base.lerp(Color(1.0, 0.7, 0.15), shade * 0.5))
					if top_open:
						var pts2 := PackedVector2Array()
						for i in 9:
							pts2.append(Vector2(x0 + i * 4, y0 + 4 + sin(t * 3.0 + (x0 + i * 4) * 0.1) * 2.0))
						draw_polyline(pts2, Color(1.0, 0.9, 0.4), 3.0)
