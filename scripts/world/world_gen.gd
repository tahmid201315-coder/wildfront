extends RefCounted
## Deterministic world generator: height field, regions, terrain colours. Everything else
## (collision, decor placement, gameplay) reads from the baked grid so the world is consistent.

const DW = preload("res://scripts/core/data_world.gd")

static var ready := false
static var grid := PackedFloat32Array()      # (N+1)^2 heights
static var n_base := FastNoiseLite.new()
static var n_detail := FastNoiseLite.new()
static var n_ridge := FastNoiseLite.new()
static var n_warp := FastNoiseLite.new()
static var n_misc := FastNoiseLite.new()
static var site_base_h: Dictionary = {}
static var half := DW.WORLD_SIZE * 0.5


static func setup(seed_value: int = 1337) -> void:
	n_base.seed = seed_value
	n_base.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_base.frequency = 0.0045
	n_base.fractal_octaves = 4
	n_detail.seed = seed_value + 11
	n_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_detail.frequency = 0.035
	n_detail.fractal_octaves = 2
	n_ridge.seed = seed_value + 23
	n_ridge.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_ridge.frequency = 0.0075
	n_ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	n_ridge.fractal_octaves = 4
	n_warp.seed = seed_value + 37
	n_warp.frequency = 0.012
	n_misc.seed = seed_value + 51
	n_misc.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_misc.frequency = 0.06
	ready = false


# --------------------------------------------------------------------- regions
static func _warp(x: float, z: float) -> Vector2:
	return Vector2(x + n_warp.get_noise_2d(x, z) * 26.0, z + n_warp.get_noise_2d(x + 500.0, z - 300.0) * 26.0)


## Normalised region weights (sum to 1). Weighted by distance relative to each region's radius.
static func region_weights(x: float, z: float) -> Dictionary:
	var p := _warp(x, z)
	var w := {}
	var total := 0.0
	for id in DW.REGION_ORDER:
		var r: Dictionary = DW.REGIONS[id]
		var c: Vector2 = r["center"]
		var d := p.distance_to(c) / float(r["radius"])
		var v := exp(-d * d * 2.6)
		w[id] = v
		total += v
	if total < 0.0001:
		w["coast"] = 1.0
		total = 1.0
	for id in w.keys():
		w[id] = float(w[id]) / total
	return w


static func region_at(x: float, z: float) -> String:
	var w := region_weights(x, z)
	var best := "coast"
	var bv := -1.0
	for id in w:
		if float(w[id]) > bv:
			bv = float(w[id])
			best = id
	return best


static func land_factor(x: float, z: float) -> float:
	var p := _warp(x, z)
	var f := -1.0
	for id in DW.REGION_ORDER:
		var r: Dictionary = DW.REGIONS[id]
		var d := p.distance_to(r["center"] as Vector2) / (float(r["radius"]) * 1.32)
		f = maxf(f, 1.0 - d)
	return f


# --------------------------------------------------------------------- heights
static func _terrace(h: float, step: float, sharp: float) -> float:
	var t := h / step
	var fl := floorf(t)
	var fr := t - fl
	return (fl + smoothstep(0.5 - sharp, 0.5 + sharp, fr)) * step


static func region_height(id: String, x: float, z: float) -> float:
	var b := n_base.get_noise_2d(x, z)
	var d := n_detail.get_noise_2d(x, z)
	match id:
		"coast":
			var dune := sin(x * 0.045 + b * 3.0) * 0.8
			var inland := smoothstep(0.02, 0.5, land_factor(x, z))
			return 1.4 + inland * 5.5 + b * 2.6 + d * 0.9 + dune * 0.6
		"forest":
			return 13.0 + b * 10.5 + d * 2.6 + n_ridge.get_noise_2d(x * 0.6, z * 0.6) * 4.0
		"highlands":
			var r := n_ridge.get_noise_2d(x, z)            # -1..1, ridged -> mostly positive crests
			var m := clampf((r + 0.35) * 0.9, 0.0, 1.4)
			var base := 34.0 + m * 62.0 + b * 10.0
			base = lerpf(base, _terrace(base, 9.0, 0.16), 0.55)
			return base + d * 2.2
		"ashen":
			var c: Vector2 = (DW.SITES["furnace"]["pos"] as Vector2)
			var dc := Vector2(x, z).distance_to(c)
			var rim := 46.0 * exp(-pow((dc - 40.0) / 17.0, 2.0))
			var floor_dip := -22.0 * exp(-pow(dc / 24.0, 2.0))
			return 17.0 + b * 7.0 + d * 1.6 + rim + floor_dip
		"core":
			return 30.0 + b * 3.0 + d * 0.8
	return 0.0


static func raw_height(x: float, z: float) -> float:
	var w := region_weights(x, z)
	var h := 0.0
	for id in w:
		var wv: float = w[id]
		if wv > 0.002:
			h += wv * region_height(id, x, z)
	# core caldera ring with an entrance toward the ashen expanse
	var cc: Vector2 = DW.REGIONS["core"]["center"]
	var rel := Vector2(x, z) - cc
	var dc := rel.length()
	var plate := 1.0 - smoothstep(58.0, 96.0, dc)
	h = lerpf(h, 31.0 + n_misc.get_noise_2d(x, z) * 0.6, plate)
	var ang := atan2(rel.y, rel.x)
	var gap_dir := atan2(-1.0, 0.0)                         # north (-z)
	var da := absf(wrapf(ang - gap_dir, -PI, PI))
	var gap := smoothstep(0.30, 0.52, da)                    # 0 in the entrance, 1 elsewhere
	h += 48.0 * exp(-pow((dc - 82.0) / 13.0, 2.0)) * gap
	# island shore profile
	var f := land_factor(x, z)
	var land := smoothstep(-0.02, 0.24, f)
	h = lerpf(-14.0, h, land)
	return h


static func _site_blend(x: float, z: float, h: float) -> float:
	for id in DW.SITES:
		var s: Dictionary = DW.SITES[id]
		var p: Vector2 = s["pos"]
		var fl: float = s["flat"]
		var d := Vector2(x, z).distance_to(p)
		if d < fl + 18.0:
			var t := 1.0 - smoothstep(fl, fl + 18.0, d)
			h = lerpf(h, float(site_base_h.get(id, h)), t)
	return h


static func build_grid(progress: Callable = Callable()) -> void:
	var n: int = DW.GRID_N
	# pass 1: base heights at sites
	site_base_h.clear()
	for id in DW.SITES:
		var p: Vector2 = DW.SITES[id]["pos"]
		var hh := raw_height(p.x, p.y)
		if id == "grove" or id == "furnace":
			hh = maxf(hh, 4.0)
		site_base_h[id] = maxf(hh, 2.2) if DW.SITES[id]["region"] != "core" else hh
	grid.resize((n + 1) * (n + 1))
	for iz in n + 1:
		var z := -half + iz * DW.CELL
		for ix in n + 1:
			var x := -half + ix * DW.CELL
			grid[iz * (n + 1) + ix] = _site_blend(x, z, raw_height(x, z))
		if progress.is_valid() and iz % 8 == 0:
			progress.call(float(iz) / float(n))
	ready = true


# ------------------------------------------------------------------- queries
static func height_at(x: float, z: float) -> float:
	if not ready:
		return _site_blend(x, z, raw_height(x, z))
	var n: int = DW.GRID_N
	var fx := (x + half) / DW.CELL
	var fz := (z + half) / DW.CELL
	if fx < 0.0 or fz < 0.0 or fx > n or fz > n:
		return -14.0
	var ix := mini(int(fx), n - 1)
	var iz := mini(int(fz), n - 1)
	var tx := fx - ix
	var tz := fz - iz
	var w := n + 1
	var h00 := grid[iz * w + ix]
	var h10 := grid[iz * w + ix + 1]
	var h01 := grid[(iz + 1) * w + ix]
	var h11 := grid[(iz + 1) * w + ix + 1]
	# triangle split matching the render mesh (diagonal from 00 to 11)
	if tx >= tz:
		return h00 + (h10 - h00) * tx + (h11 - h10) * tz
	return h00 + (h11 - h01) * tx + (h01 - h00) * tz


static func slope_at(x: float, z: float) -> float:
	var e := DW.CELL
	var dx := height_at(x + e, z) - height_at(x - e, z)
	var dz := height_at(x, z + e) - height_at(x, z - e)
	return Vector2(dx, dz).length() / (2.0 * e)


static func normal_at(x: float, z: float) -> Vector3:
	var e := DW.CELL
	var dx := height_at(x + e, z) - height_at(x - e, z)
	var dz := height_at(x, z + e) - height_at(x, z - e)
	return Vector3(-dx, 2.0 * e, -dz).normalized()


## True when the point is dry land the player can build/spawn on.
static func is_land(x: float, z: float, margin: float = 0.4) -> bool:
	return height_at(x, z) > DW.SEA_LEVEL + margin


# ------------------------------------------------------------------- colours
const COL_SAND := Color(0.80, 0.72, 0.50)
const COL_WET_SAND := Color(0.58, 0.50, 0.34)
const COL_GRASS := Color(0.30, 0.52, 0.20)
const COL_GRASS_DRY := Color(0.52, 0.55, 0.24)
const COL_FOREST := Color(0.16, 0.34, 0.13)
const COL_MOSS := Color(0.22, 0.42, 0.18)
const COL_DIRT := Color(0.34, 0.25, 0.16)
const COL_ROCK := Color(0.46, 0.44, 0.42)
const COL_ROCK_WARM := Color(0.52, 0.40, 0.31)
const COL_SNOW := Color(0.92, 0.94, 0.98)
const COL_ASH := Color(0.20, 0.18, 0.18)
const COL_ASH_LIGHT := Color(0.34, 0.31, 0.30)
const COL_SCORCH := Color(0.10, 0.08, 0.08)
const COL_CORE := Color(0.15, 0.17, 0.22)
const COL_CORE_LIGHT := Color(0.26, 0.30, 0.36)


## Returns Color(r,g,b, glow_mask). glow_mask is used for lava / energy lines (emission in shader).
static func terrain_color(x: float, z: float, h: float, slope: float, w: Dictionary) -> Color:
	var n1 := n_misc.get_noise_2d(x, z)
	var n2 := n_detail.get_noise_2d(x * 1.7 + 90.0, z * 1.7 - 40.0)
	var col := Color(0, 0, 0)
	var glow := 0.0
	# coast
	var wc: float = w.get("coast", 0.0)
	if wc > 0.002:
		var c := COL_GRASS.lerp(COL_GRASS_DRY, clampf(n1 * 1.5 + 0.4, 0.0, 1.0))
		var sand_t := 1.0 - smoothstep(1.6, 3.0, h + n2 * 0.8)
		c = c.lerp(COL_SAND, sand_t)
		c = c.lerp(COL_WET_SAND, 1.0 - smoothstep(-0.3, 0.9, h))
		col += c * wc
	var wf: float = w.get("forest", 0.0)
	if wf > 0.002:
		var c := COL_FOREST.lerp(COL_MOSS, clampf(n1 * 1.6 + 0.5, 0.0, 1.0))
		c = c.lerp(COL_DIRT, clampf(smoothstep(0.55, 0.85, n2 + 0.2) * 0.55, 0.0, 1.0))
		col += c * wf
	var wh: float = w.get("highlands", 0.0)
	if wh > 0.002:
		var c := COL_ROCK.lerp(COL_ROCK_WARM, clampf(n1 * 1.5 + 0.5, 0.0, 1.0))
		c = c.lerp(COL_GRASS_DRY * 0.8, (1.0 - smoothstep(34.0, 50.0, h)) * 0.7)
		c = c.lerp(COL_SNOW, smoothstep(90.0, 102.0, h + n2 * 4.0) * (1.0 - smoothstep(0.7, 1.1, slope)))
		col += c * wh
	var wa: float = w.get("ashen", 0.0)
	if wa > 0.002:
		var c := COL_ASH.lerp(COL_ASH_LIGHT, clampf(n1 * 1.4 + 0.5, 0.0, 1.0))
		c = c.lerp(COL_SCORCH, smoothstep(0.1, 0.5, n2) * 0.8)
		# lava veins: thin bands of a ridged-looking noise
		var vein := 1.0 - absf(n_ridge.get_noise_2d(x * 1.5 + 200.0, z * 1.5))
		var lava := smoothstep(0.93, 0.985, vein) * wa
		glow = maxf(glow, lava)
		col += c * wa
	var wk: float = w.get("core", 0.0)
	if wk > 0.002:
		var c := COL_CORE.lerp(COL_CORE_LIGHT, clampf(n1 * 1.3 + 0.5, 0.0, 1.0))
		var grid_line := smoothstep(0.92, 0.98, absf(sin(x * 0.4)) * absf(cos(z * 0.4)) + 0.0)
		glow = maxf(glow, grid_line * wk * 0.6)
		col += c * wk
	var total := col
	# slope rock overlay for every region
	var rock := COL_ROCK.lerp(COL_ROCK_WARM, clampf(n1 + 0.5, 0.0, 1.0))
	if wa > 0.5:
		rock = COL_ASH_LIGHT
	if wk > 0.5:
		rock = COL_CORE_LIGHT
	var rt := smoothstep(0.55, 0.95, slope) 
	total = Color(total.r, total.g, total.b).lerp(rock, rt)
	return Color(total.r, total.g, total.b, glow)


# ------------------------------------------------------------- baked arrays
static var colors := PackedColorArray()
static var normals := PackedVector3Array()


## Bakes per-vertex colours and normals for the whole grid (call from a worker thread).
static func build_vertex_data(progress: Callable = Callable()) -> void:
	var n: int = DW.GRID_N
	var w := n + 1
	colors.resize(w * w)
	normals.resize(w * w)
	for iz in w:
		var z := -half + iz * DW.CELL
		for ix in w:
			var x := -half + ix * DW.CELL
			var i := iz * w + ix
			var hl := grid[iz * w + maxi(ix - 1, 0)]
			var hr := grid[iz * w + mini(ix + 1, n)]
			var hu := grid[maxi(iz - 1, 0) * w + ix]
			var hd := grid[mini(iz + 1, n) * w + ix]
			var nx := hl - hr
			var nz := hu - hd
			var nrm := Vector3(nx, 2.0 * DW.CELL, nz).normalized()
			normals[i] = nrm
			var slope := sqrt(nx * nx + nz * nz) / (2.0 * DW.CELL)
			var wts := region_weights(x, z)
			colors[i] = terrain_color(x, z, grid[i], slope, wts)
		if progress.is_valid() and iz % 8 == 0:
			progress.call(float(iz) / float(w))
