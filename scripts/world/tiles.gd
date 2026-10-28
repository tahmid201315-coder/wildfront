class_name Tiles
extends RefCounted
## Tile ids, classification and procedural tile art (generated per region at load time).

const AIR := 0
const SOLID := 1
const BRICK := 2
const ONEWAY := 3
const SPIKE := 4
const LADDER := 5
const WATER := 6
const LAVA := 7
const BREAK := 8
const ICE := 9
const GATE := 10
const THORN := 11

const CHAR_TO_TILE := {
	"#": SOLID, "B": BRICK, "=": ONEWAY, "^": SPIKE, "H": LADDER, "~": WATER, "L": LAVA, "X": BREAK, "I": ICE, "G": GATE, "T": THORN,
}

const SIZE := 32


static func is_solid(t: int) -> bool:
	return t == SOLID or t == BRICK or t == BREAK or t == ICE or t == GATE


static func is_hazard(t: int) -> bool:
	return t == SPIKE or t == LAVA or t == THORN


static func hazard_damage(t: int) -> float:
	match t:
		SPIKE: return 18.0
		LAVA: return 28.0
		THORN: return 14.0
	return 0.0


static func _h(x: int, y: int, s: int) -> float:
	var n: int = (x * 374761393 + y * 668265263 + s * 982451653) & 0x7fffffff
	n = (n ^ (n >> 13)) * 1274126177 & 0x7fffffff
	return float(n & 0xffff) / 65535.0


static func _noise(x: float, y: float, s: int, cell: int) -> float:
	var xi := int(floor(x / cell))
	var yi := int(floor(y / cell))
	var fx := x / cell - xi
	var fy := y / cell - yi
	var a := _h(xi, yi, s)
	var b := _h(xi + 1, yi, s)
	var c := _h(xi, yi + 1, s)
	var d := _h(xi + 1, yi + 1, s)
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


## Builds all tile images for a region theme. Returns {tile_id: [Image variants], "cap": [Image], "decor": ...}
static func build_atlas(theme: Dictionary, region_id: String) -> Dictionary:
	var atlas := {}
	var ground: Color = theme["ground"]
	var stone: Color = theme["stone"]
	var accent: Color = theme["accent"]
	var glow: Color = theme["glow"]
	atlas[SOLID] = _variants(4, func(v): return _earth(ground, v))
	atlas[BRICK] = _variants(4, func(v): return _bricks(stone, v, region_id))
	atlas[ICE] = _variants(4, func(v): return _ice(v))
	atlas[BREAK] = _variants(2, func(v): return _breakable(stone, glow, v))
	atlas[GATE] = _variants(1, func(v): return _gate(stone, glow))
	atlas[ONEWAY] = _variants(2, func(v): return _oneway(stone, accent, v))
	atlas[SPIKE] = _variants(2, func(v): return _spikes(v, region_id, stone))
	atlas[THORN] = _variants(2, func(v): return _thorns(v, accent))
	atlas[LADDER] = _variants(1, func(v): return _ladder(stone))
	atlas["cap"] = _variants(4, func(v): return _cap(region_id, accent, ground, v))
	return atlas


static func _variants(n: int, f: Callable) -> Array:
	var out: Array = []
	for i in n:
		out.append(f.call(i))
	return out


static func _blank() -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


static func _earth(ground: Color, v: int) -> Image:
	var img := _blank()
	for y in SIZE:
		for x in SIZE:
			var n := _noise(x + v * 40, y + v * 17, 3, 6) * 0.6 + _noise(x + v * 5, y, 9, 2) * 0.4
			var c := ground.lightened(0.0).darkened(0.25).lerp(ground.lightened(0.18), n)
			if _h(x, y, v + 21) > 0.965:
				c = c.lightened(0.25)
			img.set_pixel(x, y, c)
	return img


static func _bricks(stone: Color, v: int, region_id: String) -> Image:
	var img := _blank()
	for y in SIZE:
		for x in SIZE:
			var row := y / 16
			var off := 16 if row % 2 == 1 else 0
			var bx := (x + off) % 32
			var edge := (y % 16 == 0) or (bx % 32 == 0) or (bx % 32 == 31 and false)
			var n := _noise(x + v * 31, y, 11, 4)
			var c := stone.darkened(0.15).lerp(stone.lightened(0.15), n)
			if edge:
				c = stone.darkened(0.45)
			elif y % 16 == 1 or (bx % 32) == 1:
				c = c.lightened(0.12)
			if _h(x, y, v + 7) > 0.97:
				c = c.darkened(0.2)
			img.set_pixel(x, y, c)
	return img


static func _ice(v: int) -> Image:
	var img := _blank()
	var base := Color(0.62, 0.82, 0.95)
	for y in SIZE:
		for x in SIZE:
			var n := _noise(x + v * 13, y + v * 9, 5, 8)
			var c := base.darkened(0.15).lerp(Color(0.9, 0.97, 1.0), n)
			if abs(float(x) - float(y) - 8.0 * v) < 1.5 and v % 2 == 0:
				c = c.lightened(0.3)
			img.set_pixel(x, y, c)
	for i in SIZE:
		img.set_pixel(i, 0, Color(1, 1, 1, 0.9))
		img.set_pixel(0, i, Color(0.85, 0.95, 1.0, 0.9))
	return img


static func _breakable(stone: Color, glow: Color, v: int) -> Image:
	var img := _bricks(stone.darkened(0.1), v, "")
	# visible hairline cracks so the wall reads as breakable
	var x := 6 + v * 10
	for y in range(4, 30):
		x += int(round(_h(y, v, 4) * 2.0 - 1.0))
		x = clampi(x, 2, 29)
		img.set_pixel(x, y, Color(0.08, 0.06, 0.05))
		if y % 5 == 0:
			img.set_pixel(clampi(x + 1, 0, 31), y, glow.darkened(0.4))
	return img


static func _gate(stone: Color, glow: Color) -> Image:
	var img := _blank()
	for y in SIZE:
		for x in SIZE:
			var c := stone.darkened(0.35)
			if x % 8 == 0 or x % 8 == 7:
				c = stone.darkened(0.55)
			img.set_pixel(x, y, c)
	for y in range(6, 26):
		for x in range(12, 20):
			var dx := absf(float(x) - 15.5) + absf(float(y) - 15.5) * 0.5
			if dx < 5.0:
				img.set_pixel(x, y, glow.lerp(Color.WHITE, 0.2).darkened(0.1 + dx * 0.05))
	return img


static func _oneway(stone: Color, accent: Color, v: int) -> Image:
	var img := _blank()
	for y in range(0, 9):
		for x in SIZE:
			var c := stone.lerp(stone.lightened(0.25), _noise(x + v * 20, y, 2, 4))
			if y == 0:
				c = accent.lightened(0.15)
			elif y >= 7:
				c = stone.darkened(0.4)
			img.set_pixel(x, y, c)
	for x in range(2, SIZE, 8):
		for y in range(9, 13):
			img.set_pixel(x, y, stone.darkened(0.35))
	return img


static func _spikes(v: int, region_id: String, stone: Color) -> Image:
	var img := _blank()
	var col := Color(0.78, 0.82, 0.88)
	if region_id == "frostfall":
		col = Color(0.8, 0.95, 1.0)
	elif region_id == "ember":
		col = Color(0.45, 0.4, 0.4)
	for k in 4:
		var cx := 4 + k * 8
		for y in range(10, 32):
			var half := int((float(y) - 10.0) / 22.0 * 4.0) + 1
			for x in range(cx - half, cx + half):
				if x >= 0 and x < SIZE:
					var c := col.darkened(0.25 if x < cx else 0.0)
					if y < 14:
						c = c.lightened(0.3)
					img.set_pixel(x, y, c)
	for x in SIZE:
		img.set_pixel(x, 31, stone.darkened(0.5))
		img.set_pixel(x, 30, stone.darkened(0.3))
	return img


static func _thorns(v: int, accent: Color) -> Image:
	var img := _blank()
	var green := Color(0.2, 0.42, 0.18)
	for k in 5:
		var x0 := 3 + k * 6 + int(_h(k, v, 3) * 3.0)
		var h := 12 + int(_h(k, v, 8) * 14.0)
		for y in range(32 - h, 32):
			var t := float(y - (32 - h)) / float(h)
			var half := int(t * 3.0)
			for x in range(x0 - half, x0 + half + 1):
				if x >= 0 and x < SIZE:
					img.set_pixel(x, y, green.lerp(accent.darkened(0.3), 1.0 - t) if t < 0.3 else green)
	return img


static func _ladder(stone: Color) -> Image:
	var img := _blank()
	var wood := Color(0.55, 0.38, 0.2)
	for y in SIZE:
		for x in [7, 8, 23, 24]:
			img.set_pixel(x, y, wood.darkened(0.2 if x in [7, 23] else 0.0))
	for y in range(3, SIZE, 10):
		for x in range(8, 24):
			img.set_pixel(x, y, wood.lightened(0.1))
			img.set_pixel(x, y + 1, wood.darkened(0.2))
	return img


## Transparent top-edge overlay (grass, snow, crust...) drawn on solid tiles that have air above.
static func _cap(region_id: String, accent: Color, ground: Color, v: int) -> Image:
	var img := _blank()
	var depth := 6
	for x in SIZE:
		var d := depth + int(_h(x, v, 5) * 4.0) - 2
		for y in d:
			var t := float(y) / float(d)
			var c := accent
			match region_id:
				"meadows", "thornwild":
					c = accent.lerp(accent.darkened(0.35), t)
				"frostfall":
					c = Color(0.97, 0.99, 1.0).lerp(Color(0.8, 0.9, 1.0), t)
				"ember":
					c = Color(0.12, 0.08, 0.07).lerp(accent.darkened(0.2), t * t) if _h(x, y, 31 + v) > 0.12 else accent
				"observatory":
					c = accent.darkened(0.3).lerp(accent.darkened(0.6), t)
				"clockwork":
					c = accent.darkened(0.2).lerp(accent.darkened(0.55), t)
				"eclipse":
					c = accent.darkened(0.2).lerp(accent.darkened(0.6), t)
			img.set_pixel(x, y, c)
		if region_id in ["meadows", "thornwild"] and _h(x, v, 12) > 0.6:
			var bl := 2 + int(_h(x, v, 13) * 3.0)
			for k in bl:
				if depth - 2 - k >= 0:
					pass
	return img
