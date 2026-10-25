extends RefCounted
## Procedural model library for world decor and resource nodes. Every mesh is a single surface
## with vertex colours; variants are seeded so the world is varied but deterministic.

const MK = preload("res://scripts/gfx/mesh_kit.gd")

static var _cache: Dictionary = {}

const BARK := Color(0.36, 0.25, 0.16)
const BARK_PALE := Color(0.55, 0.47, 0.36)
const LEAF_PALM := Color(0.18, 0.46, 0.16)
const LEAF_PALM_TIP := Color(0.42, 0.62, 0.2)


static func get_mesh(kind: String, variant: int = 0) -> ArrayMesh:
	var key := "%s_%d" % [kind, variant]
	if _cache.has(key):
		return _cache[key]
	var m: ArrayMesh = _build(kind, variant)
	_cache[key] = m
	return m


static func variants(kind: String) -> int:
	match kind:
		"palm", "broadleaf", "pine", "dead_tree", "rock", "rock_big", "bush", "fern", "grass", "mushroom", "crystal", "reed":
			return 3
	return 1


static func _build(kind: String, v: int) -> ArrayMesh:
	var b := MK.Builder.new(hash(kind) + v * 977)
	match kind:
		"palm": _palm(b, v)
		"broadleaf": _broadleaf(b, v)
		"pine": _pine(b, v)
		"dead_tree": _dead_tree(b, v, false)
		"burnt_tree": _dead_tree(b, v, true)
		"rock": _rock(b, v, 1.0, Color(0.50, 0.48, 0.45))
		"rock_big": _rock_formation(b, v)
		"rock_dark": _rock(b, v, 1.0, Color(0.20, 0.18, 0.19))
		"rock_ash": _rock_formation_dark(b, v)
		"bush": _bush(b, v)
		"fern": _fern(b, v)
		"grass": _grass(b, v, Color(0.30, 0.55, 0.20), Color(0.62, 0.78, 0.30))
		"grass_dry": _grass(b, v, Color(0.50, 0.50, 0.22), Color(0.80, 0.72, 0.38))
		"mushroom": _mushroom(b, v, false)
		"mushroom_giant": _mushroom(b, v, true)
		"crystal": _crystal(b, v, Color(0.35, 0.85, 1.0))
		"crystal_red": _crystal(b, v, Color(1.0, 0.45, 0.25))
		"reed": _reed(b, v)
		"iron_ore": _ore(b, v, Color(0.55, 0.52, 0.50), Color(0.72, 0.36, 0.20))
		"copper_ore": _ore(b, v, Color(0.50, 0.50, 0.48), Color(0.25, 0.70, 0.55))
		"coal_rock": _ore(b, v, Color(0.18, 0.17, 0.18), Color(0.95, 0.40, 0.12))
		"flower": _flowers(b, v)
		"log": _log(b)
		"stump": _stump(b)
		"shell": _shell_pile(b, v)
		"vent": _vent(b)
		"wreck_part": _wreck_part(b, v)
		_: b.box(Vector3(1, 1, 1), Color(1, 0, 1))
	var mat: Material
	if kind.begins_with("crystal") or kind in ["coal_rock", "mushroom_giant"]:
		mat = MK.style_material(0.0, 0.55, 0.65)
	elif kind in ["grass", "grass_dry", "fern", "bush", "palm", "broadleaf", "pine", "reed", "flower"]:
		mat = MK.style_material(0.35, 0.18, 0.0)
	else:
		mat = MK.style_material(0.0, 0.2, 0.0)
	return b.commit(mat)


# ---------------------------------------------------------------- trees
static func _palm(b: MK.Builder, v: int) -> void:
	var lean := 0.9 + v * 0.35
	var h := 6.0 + v * 0.9
	var pts: Array = []
	var rad: Array = []
	for i in 8:
		var t := i / 7.0
		pts.append(Vector3(sin(t * 1.3) * lean * t, t * h, cos(t * 1.7) * 0.3 * t))
		rad.append(lerpf(0.30, 0.15, t))
	b.tube(pts, rad, BARK_PALE, 7)
	# trunk rings
	for i in range(1, 8):
		var p: Vector3 = pts[i]
		b.cyl(float(rad[i]) + 0.04, float(rad[i]) + 0.04, 0.09, BARK * 0.9, p, Vector3.ZERO, 7, false)
	var top: Vector3 = pts[7]
	b.sway = 1.0
	for f in 10:
		var a := TAU * f / 10.0 + v
		var dir := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-dir.z, 0, dir.x)
		var droop := 0.55 + (f % 2) * 0.35
		var prev_c := top
		var wid := 0.55
		for s in 5:
			var t0 := s / 5.0
			var t1 := (s + 1) / 5.0
			var pa := top + dir * (t0 * 3.4) + Vector3(0, sin(t0 * 2.4) * 1.1 - t0 * t0 * 3.0 * droop, 0)
			var pb := top + dir * (t1 * 3.4) + Vector3(0, sin(t1 * 2.4) * 1.1 - t1 * t1 * 3.0 * droop, 0)
			var wa := wid * (1.0 - t0 * 0.85)
			var wb := wid * (1.0 - t1 * 0.85)
			var c0 := LEAF_PALM.lerp(LEAF_PALM_TIP, t0)
			var c1 := LEAF_PALM.lerp(LEAF_PALM_TIP, t1)
			b.card(pa - side * wa, pa + side * wa, pb + side * wb, pb - side * wb, c0, t1, c1)
	b.sway = 0.0
	for c in 3:
		var a := c * 2.1
		b.sphere(Vector3(0.2, 0.22, 0.2), Color(0.26, 0.18, 0.1), top + Vector3(cos(a) * 0.25, -0.35, sin(a) * 0.25), Vector3.ZERO, 4, 6)


static func _broadleaf(b: MK.Builder, v: int) -> void:
	var h := 5.2 + v * 0.8
	var lean := (v - 1) * 0.25
	var pts: Array = []
	var rad: Array = []
	for i in 6:
		var t := i / 5.0
		pts.append(Vector3(lean * t * t, t * h, sin(t * 3.0 + v) * 0.12))
		rad.append(lerpf(0.42, 0.16, t))
	b.tube(pts, rad, BARK, 7, 0.0, BARK * 1.1)
	# root flare
	for r in 4:
		var a := r * TAU / 4.0 + v
		b.cyl(0.12, 0.03, 0.9, BARK * 0.9, Vector3(cos(a) * 0.28, 0.0, sin(a) * 0.28), Vector3(sin(a) * 38, 0, -cos(a) * 38), 5, false)
	var top: Vector3 = pts[5]
	var cols := [Color(0.20, 0.45, 0.16), Color(0.28, 0.55, 0.20), Color(0.16, 0.38, 0.14)]
	var bc: Color = cols[v % 3]
	var canopy := [Vector3(0, -0.9, 0), Vector3(1.5, -0.4, 0.4), Vector3(-1.4, -0.5, -0.6), Vector3(0.3, 0.2, 1.4), Vector3(-0.2, 0.3, -1.4), Vector3(0.1, 1.1, 0.0)]
	for i in canopy.size():
		var cp: Vector3 = canopy[i]
		var s := 1.55 - i * 0.07 + (v * 0.1)
		b.blob(Vector3(s, s * 0.82, s), bc, top + cp, 0.2, 1, Vector3(0, i * 40, 0), 0.7, bc.lightened(0.32))
	# a couple of branches
	b.tube([top + Vector3(0, -2.0, 0), top + Vector3(0.9, -1.3, 0.2), top + Vector3(1.6, -0.9, 0.4)], [0.12, 0.09, 0.06], BARK, 5)
	b.tube([top + Vector3(0, -1.7, 0), top + Vector3(-0.8, -1.1, -0.3), top + Vector3(-1.4, -0.7, -0.5)], [0.11, 0.08, 0.05], BARK, 5)


static func _pine(b: MK.Builder, v: int) -> void:
	var h := 9.0 + v * 1.6
	b.cyl(0.36, 0.14, h * 0.7, Color(0.30, 0.2, 0.13), Vector3.ZERO, Vector3.ZERO, 7)
	var tiers := 6
	for i in tiers:
		var t := i / float(tiers - 1)
		var y := h * 0.22 + t * h * 0.74
		var r := lerpf(2.5, 0.5, t) + v * 0.1
		var c := Color(0.09, 0.30, 0.15).lerp(Color(0.18, 0.46, 0.22), t)
		b.sway = 0.55 + t * 0.4
		b.cyl(r, 0.0, 2.1 - t * 0.7, c, Vector3(0, y, 0), Vector3(0, i * 30, 0), 7, true, 0.8)
		b.cyl(r * 1.08, r * 0.95, 0.18, c * 0.7, Vector3(0, y - 0.05, 0), Vector3(0, i * 30, 0), 7, false, 0.6)
	b.sway = 0.0


static func _dead_tree(b: MK.Builder, v: int, burnt: bool) -> void:
	var col := Color(0.14, 0.11, 0.10) if burnt else Color(0.42, 0.36, 0.30)
	var h := 4.5 + v * 0.8
	var pts: Array = []
	var rad: Array = []
	for i in 6:
		var t := i / 5.0
		pts.append(Vector3(sin(t * 2.0 + v) * 0.35, t * h, cos(t * 2.4) * 0.2))
		rad.append(lerpf(0.34, 0.05, t))
	b.tube(pts, rad, col, 6, 0.0, col * 1.15)
	for br in 5:
		var t := 0.35 + br * 0.12
		var base: Vector3 = pts[int(t * 5)]
		var a := br * 2.4 + v
		var dir := Vector3(cos(a), 0.6, sin(a)).normalized()
		var len := 1.8 - br * 0.2
		b.tube([base, base + dir * len * 0.5 + Vector3(0, 0.2, 0), base + dir * len + Vector3(0, 0.1, 0)], [0.1, 0.07, 0.025], col, 5)
	if burnt:
		for e in 4:
			var p: Vector3 = pts[1 + e]
			b.sphere(Vector3(0.08, 0.12, 0.08), Color(1.0, 0.4, 0.1), p + Vector3(0.28, 0.0, 0.0), Vector3.ZERO, 3, 5)


static func _bush(b: MK.Builder, v: int) -> void:
	var cols := [Color(0.22, 0.48, 0.18), Color(0.30, 0.52, 0.22), Color(0.18, 0.40, 0.18)]
	var c: Color = cols[v % 3]
	for i in 4:
		var a := i * 1.9 + v
		b.blob(Vector3(0.7, 0.55, 0.7), c, Vector3(cos(a) * 0.4, 0.4, sin(a) * 0.4), 0.2, 1, Vector3.ZERO, 0.6, c.lightened(0.25))
	if v == 1:
		for i in 6:
			var a := i * 1.1
			b.sphere(Vector3(0.07, 0.07, 0.07), Color(0.85, 0.15, 0.2), Vector3(cos(a) * 0.7, 0.45 + (i % 3) * 0.12, sin(a) * 0.7), Vector3.ZERO, 3, 5)


static func _fern(b: MK.Builder, v: int) -> void:
	b.sway = 1.0
	var n := 8 + v * 2
	for f in n:
		var a := TAU * f / n + v
		var dir := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-dir.z, 0, dir.x)
		var len := 1.3 + (f % 3) * 0.2
		for s in 3:
			var t0 := s / 3.0
			var t1 := (s + 1) / 3.0
			var pa := dir * t0 * len + Vector3(0, sin(t0 * 1.8) * 0.5, 0)
			var pb := dir * t1 * len + Vector3(0, sin(t1 * 1.8) * 0.5, 0)
			var wa := 0.16 * (1.0 - t0 * 0.7)
			var wb := 0.16 * (1.0 - t1 * 0.7)
			b.card(pa - side * wa, pa + side * wa, pb + side * wb, pb - side * wb, Color(0.14, 0.42, 0.16), t1, Color(0.32, 0.62, 0.24))
	b.sway = 0.0


static func _grass(b: MK.Builder, v: int, c0: Color, c1: Color) -> void:
	b.ao = 0.5
	for i in 7:
		var a := i * 0.9 + v * 0.3
		var base := Vector3(cos(a) * 0.12, 0, sin(a) * 0.12)
		var dir := Vector3(cos(a * 2.3), 0, sin(a * 2.3))
		var h := 0.45 + (i % 3) * 0.2
		var side := Vector3(-dir.z, 0, dir.x) * 0.045
		b.card(base - side, base + side, base + dir * 0.18 + Vector3(0, h, 0), base + dir * 0.18 + Vector3(0, h, 0), c0, 1.0, c1)


static func _flowers(b: MK.Builder, v: int) -> void:
	var cols := [Color(0.95, 0.85, 0.25), Color(0.9, 0.35, 0.5), Color(0.85, 0.9, 1.0)]
	for i in 5:
		var a := i * 1.3
		var base := Vector3(cos(a) * 0.25, 0, sin(a) * 0.25)
		b.cyl(0.015, 0.012, 0.35, Color(0.2, 0.5, 0.2), base, Vector3.ZERO, 4, false, 0.8)
		b.sphere(Vector3(0.07, 0.04, 0.07), cols[(i + v) % 3], base + Vector3(0, 0.37, 0), Vector3.ZERO, 3, 6, 0.9)


static func _reed(b: MK.Builder, v: int) -> void:
	b.sway = 1.0
	for i in 8:
		var a := i * 0.8
		var base := Vector3(cos(a) * 0.2, 0, sin(a) * 0.2)
		var h := 1.2 + (i % 4) * 0.35
		b.cyl(0.02, 0.012, h, Color(0.42, 0.52, 0.22), base, Vector3(sin(a) * 6, 0, cos(a) * 6), 4, false, 1.0)
		if i % 3 == 0:
			b.cyl(0.05, 0.05, 0.2, Color(0.35, 0.22, 0.12), base + Vector3(0, h - 0.1, 0), Vector3.ZERO, 5, true, 1.0)
	b.sway = 0.0


static func _mushroom(b: MK.Builder, v: int, giant: bool) -> void:
	var cols := [Color(0.86, 0.28, 0.26), Color(0.72, 0.55, 0.85), Color(0.9, 0.62, 0.25)]
	var cap: Color = cols[v % 3]
	var count := 1 if giant else 4
	for i in count:
		var a := i * 2.0 + v
		var o := Vector3.ZERO if giant else Vector3(cos(a) * 0.45, 0, sin(a) * 0.45)
		var s := 1.0 if giant else 0.35 + (i % 3) * 0.12
		var sh := 3.2 * s if giant else 1.0 * s
		var stem_r := 0.28 if giant else 0.1 * (s / 0.35) * 0.5
		b.cyl(stem_r * 1.3, stem_r, sh, Color(0.88, 0.84, 0.74), o, Vector3.ZERO, 7)
		var r := (1.7 if giant else 0.5) * s
		b.lathe([Vector2(0.0, 0.0), Vector2(r * 0.7, 0.04 * r), Vector2(r, r * 0.22), Vector2(r * 0.85, r * 0.52), Vector2(r * 0.45, r * 0.78), Vector2(0.0, r * 0.88)], cap, 9, o + Vector3(0, sh - 0.02 * r, 0))
		for sp in 5:
			var aa := sp * 1.3 + i
			var rr := r * 0.55
			b.sphere(Vector3(r * 0.09, r * 0.04, r * 0.09), Color(1, 1, 0.85), o + Vector3(cos(aa) * rr, sh + r * 0.62 + 0.0, sin(aa) * rr), Vector3.ZERO, 3, 5)


static func _log(b: MK.Builder) -> void:
	b.cyl(0.35, 0.3, 3.4, BARK, Vector3(-1.7, 0.3, 0), Vector3(0, 0, -90), 8)
	b.sphere(Vector3(0.25, 0.1, 0.25), Color(0.4, 0.5, 0.22), Vector3(0, 0.62, 0.0), Vector3.ZERO, 3, 6)


static func _stump(b: MK.Builder) -> void:
	b.cyl(0.5, 0.4, 0.7, BARK, Vector3.ZERO, Vector3.ZERO, 8)
	b.cyl(0.38, 0.38, 0.02, Color(0.62, 0.48, 0.3), Vector3(0, 0.7, 0), Vector3.ZERO, 8)


# ---------------------------------------------------------------- rocks & ore
static func _rock(b: MK.Builder, v: int, scale: float, col: Color) -> void:
	var s := scale * (0.8 + v * 0.25)
	b.blob(Vector3(0.9 * s, 0.65 * s, 0.8 * s), col, Vector3(0, 0.35 * s, 0), 0.22, 1, Vector3(0, v * 55, 0), 0.0, col.lightened(0.18))
	if v != 1:
		b.blob(Vector3(0.45 * s, 0.35 * s, 0.4 * s), col * 0.9, Vector3(0.8 * s, 0.15 * s, 0.3 * s), 0.25, 1, Vector3.ZERO, 0.0, col.lightened(0.1))


static func _rock_formation(b: MK.Builder, v: int) -> void:
	var col := Color(0.50, 0.46, 0.42) if v != 2 else Color(0.56, 0.46, 0.38)
	b.blob(Vector3(3.2, 2.2, 2.8), col, Vector3(0, 1.4, 0), 0.2, 2, Vector3(0, v * 40, 0), 0.0, col.lightened(0.2))
	b.blob(Vector3(2.0, 2.8, 1.8), col * 0.95, Vector3(1.6, 2.0, 0.6), 0.22, 1, Vector3(0, 20, 0), 0.0, col.lightened(0.22))
	b.blob(Vector3(1.6, 1.4, 1.5), col * 0.9, Vector3(-2.2, 0.8, -0.4), 0.25, 1, Vector3.ZERO, 0.0, col.lightened(0.15))


static func _rock_formation_dark(b: MK.Builder, v: int) -> void:
	var col := Color(0.17, 0.15, 0.16)
	b.blob(Vector3(3.0, 2.4, 2.6), col, Vector3(0, 1.4, 0), 0.26, 2, Vector3(0, v * 40, 0), 0.0, col.lightened(0.25))
	b.blob(Vector3(1.6, 3.2, 1.5), col * 1.1, Vector3(1.4, 2.4, 0.4), 0.24, 1, Vector3(0, 20, 0), 0.0, col.lightened(0.3))
	b.blob(Vector3(1.0, 0.25, 1.0), Color(1.0, 0.4, 0.1), Vector3(-0.6, 0.15, 1.9), 0.1, 0, Vector3.ZERO, 0.0)


static func _crystal(b: MK.Builder, v: int, col: Color) -> void:
	b.ao = 0.15
	b.jitter = 0.1
	var n := 5 + v
	for i in n:
		var a := i * 2.4 + v
		var r := 0.12 + (i % 3) * 0.05
		var h := 0.9 + ((i * 7) % 5) * 0.28
		var tilt := Vector3(sin(a) * 18, 0, cos(a) * 18)
		var pos := Vector3(cos(a) * 0.35, 0, sin(a) * 0.35) * (0.4 if i > 0 else 0.0)
		b.cyl(r, r * 0.9, h, col.lerp(Color(1, 1, 1), 0.12 * (i % 3)), pos, tilt, 6, false)
		b.cyl(r * 0.9, 0.0, r * 2.2, col.lightened(0.35), pos + Vector3(0, h, 0).rotated(Vector3(1, 0, 0), deg_to_rad(tilt.x)).rotated(Vector3(0, 0, 1), deg_to_rad(tilt.z)), tilt, 6, true)
	b.blob(Vector3(0.7, 0.18, 0.7), Color(0.25, 0.27, 0.32), Vector3(0, 0.05, 0), 0.2, 1)


static func _ore(b: MK.Builder, v: int, rock: Color, vein: Color) -> void:
	b.blob(Vector3(1.0, 0.85, 0.9), rock, Vector3(0, 0.6, 0), 0.2, 1, Vector3(0, v * 70, 0), 0.0, rock.lightened(0.15))
	b.blob(Vector3(0.6, 0.5, 0.5), rock * 0.9, Vector3(0.75, 0.3, 0.2), 0.22, 1)
	for i in 7:
		var a := i * 0.95 + v
		var y := 0.35 + (i % 4) * 0.25
		var r := 0.9 - y * 0.15
		b.blob(Vector3(0.2, 0.17, 0.2), vein, Vector3(cos(a) * r * 0.85, y, sin(a) * r * 0.8), 0.2, 0)


static func _shell_pile(b: MK.Builder, v: int) -> void:
	for i in 5:
		var a := i * 1.4 + v
		b.sphere(Vector3(0.14, 0.05, 0.1), Color(0.92, 0.82, 0.74).lerp(Color(0.9, 0.6, 0.55), (i % 2) * 0.5), Vector3(cos(a) * 0.3, 0.04, sin(a) * 0.3), Vector3(0, a * 40, 0), 3, 6)


static func _vent(b: MK.Builder) -> void:
	b.blob(Vector3(1.1, 0.5, 1.1), Color(0.18, 0.15, 0.15), Vector3(0, 0.2, 0), 0.2, 1)
	b.cyl(0.5, 0.35, 0.5, Color(0.28, 0.2, 0.17), Vector3(0, 0.4, 0), Vector3.ZERO, 8)
	b.cyl(0.32, 0.32, 0.03, Color(1.0, 0.45, 0.12), Vector3(0, 0.88, 0), Vector3.ZERO, 8)


static func _wreck_part(b: MK.Builder, v: int) -> void:
	var metal := Color(0.62, 0.64, 0.66)
	b.box(Vector3(2.0, 0.12, 1.4), metal, Vector3(0, 0.4, 0), Vector3(8, v * 20, 4))
	b.box(Vector3(0.1, 0.5, 1.2), metal * 0.8, Vector3(0.9, 0.3, 0), Vector3(0, 0, 12))
	b.cyl(0.08, 0.08, 1.4, Color(0.3, 0.3, 0.32), Vector3(-0.6, 0.15, 0.3), Vector3(0, 0, 80), 6)
