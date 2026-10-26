extends RefCounted
## Procedural meshes for buildable structures. Origin = centre of footprint at ground (top-of-foundation for wall pieces).

const MK = preload("res://scripts/gfx/mesh_kit.gd")
const WOOD := Color(0.62, 0.44, 0.27)
const WOOD_D := Color(0.45, 0.31, 0.19)
const WOOD_L := Color(0.74, 0.56, 0.36)
const STONE := Color(0.55, 0.54, 0.52)
const IRON := Color(0.52, 0.56, 0.62)

static var _cache: Dictionary = {}


static func get_mesh(id: String) -> ArrayMesh:
	if _cache.has(id):
		return _cache[id]
	var b := MK.Builder.new(hash(id))
	b.jitter = 0.04
	var emissive := 0.0
	match id:
		"campfire": _campfire(b)
		"chest": _chest(b)
		"shelter": _shelter(b)
		"bedroll": _bedroll(b)
		"foundation": _foundation(b)
		"floor": _floor(b)
		"wall": _wall(b, false)
		"reinforced_wall": _wall(b, true)
		"door_frame": _door_frame(b)
		"door_leaf": _door_leaf(b)
		"roof": _roof(b)
		"workbench": _workbench(b)
		"cooking": _cooking(b)
		"lamp":
			_lamp(b)
			emissive = 0.8
		"barricade": _barricade(b)
		"turret":
			_turret(b)
			emissive = 0.5
		"processor":
			_processor(b)
			emissive = 0.4
		_: b.box(Vector3(1, 1, 1), Color(1, 0, 1), Vector3(0, 0.5, 0))
	var m := b.commit(MK.style_material(0.0, 0.18, emissive))
	_cache[id] = m
	return m


static func _planks(b: MK.Builder, w: float, d: float, y: float, th: float, n: int, col: Color) -> void:
	var pw := w / n
	for i in n:
		var c := col.lightened(0.05 * ((i * 7) % 3 - 1))
		b.box(Vector3(pw - 0.03, th, d), c, Vector3(-w * 0.5 + pw * (i + 0.5), y, 0))


static func _foundation(b: MK.Builder) -> void:
	b.box(Vector3(3.9, 1.6, 3.9), WOOD_D, Vector3(0, -0.7, 0))
	_planks(b, 4.0, 4.0, 0.06, 0.12, 8, WOOD)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			b.box(Vector3(0.3, 1.8, 0.3), WOOD_D.darkened(0.15), Vector3(sx * 1.85, -0.75, sz * 1.85))
	b.box(Vector3(4.0, 0.14, 0.2), WOOD_D, Vector3(0, 0.0, 1.95))
	b.box(Vector3(4.0, 0.14, 0.2), WOOD_D, Vector3(0, 0.0, -1.95))
	b.box(Vector3(0.2, 0.14, 4.0), WOOD_D, Vector3(1.95, 0.0, 0))
	b.box(Vector3(0.2, 0.14, 4.0), WOOD_D, Vector3(-1.95, 0.0, 0))


static func _floor(b: MK.Builder) -> void:
	_planks(b, 4.0, 4.0, 0.08, 0.16, 8, WOOD_L)
	b.box(Vector3(4.0, 0.3, 0.2), WOOD_D, Vector3(0, -0.12, 1.9))
	b.box(Vector3(4.0, 0.3, 0.2), WOOD_D, Vector3(0, -0.12, -1.9))
	b.box(Vector3(0.2, 0.3, 4.0), WOOD_D, Vector3(1.9, -0.12, 0))
	b.box(Vector3(0.2, 0.3, 4.0), WOOD_D, Vector3(-1.9, -0.12, 0))


static func _wall(b: MK.Builder, reinforced: bool) -> void:
	var base := Color(0.58, 0.58, 0.58) if reinforced else WOOD
	b.box(Vector3(4.0, 3.0, 0.2), base, Vector3(0, 1.5, 0))
	if reinforced:
		for i in 4:
			b.box(Vector3(0.9, 2.9, 0.26), STONE.lightened(0.05 * (i % 2)), Vector3(-1.5 + i, 1.5, 0))
		b.box(Vector3(4.1, 0.18, 0.3), IRON, Vector3(0, 0.1, 0))
		b.box(Vector3(4.1, 0.18, 0.3), IRON, Vector3(0, 2.9, 0))
		b.box(Vector3(4.1, 0.14, 0.3), IRON, Vector3(0, 1.5, 0))
	else:
		for i in 8:
			b.box(Vector3(0.46, 2.95, 0.24), WOOD.lightened(0.05 * ((i * 5) % 3 - 1)), Vector3(-1.75 + i * 0.5, 1.5, 0))
		b.box(Vector3(4.05, 0.2, 0.3), WOOD_D, Vector3(0, 0.1, 0))
		b.box(Vector3(4.05, 0.2, 0.3), WOOD_D, Vector3(0, 2.9, 0))
		b.box(Vector3(0.2, 3.0, 0.3), WOOD_D, Vector3(-1.95, 1.5, 0))
		b.box(Vector3(0.2, 3.0, 0.3), WOOD_D, Vector3(1.95, 1.5, 0))


static func _door_frame(b: MK.Builder) -> void:
	for sx in [-1, 1]:
		b.box(Vector3(1.4, 3.0, 0.22), WOOD, Vector3(sx * 1.3, 1.5, 0))
	b.box(Vector3(1.4, 0.8, 0.22), WOOD, Vector3(0, 2.6, 0))
	b.box(Vector3(4.05, 0.2, 0.3), WOOD_D, Vector3(0, 2.9, 0))
	b.box(Vector3(0.2, 3.0, 0.3), WOOD_D, Vector3(-1.95, 1.5, 0))
	b.box(Vector3(0.2, 3.0, 0.3), WOOD_D, Vector3(1.95, 1.5, 0))
	b.box(Vector3(0.14, 2.2, 0.3), WOOD_D, Vector3(-0.72, 1.1, 0))
	b.box(Vector3(0.14, 2.2, 0.3), WOOD_D, Vector3(0.72, 1.1, 0))


static func _door_leaf(b: MK.Builder) -> void:
	# pivot at hinge (x=0), leaf extends to +x
	b.box(Vector3(1.3, 2.15, 0.1), WOOD_L, Vector3(0.65, 1.08, 0))
	b.box(Vector3(1.3, 0.12, 0.14), WOOD_D, Vector3(0.65, 0.3, 0))
	b.box(Vector3(1.3, 0.12, 0.14), WOOD_D, Vector3(0.65, 1.8, 0))
	b.sphere(Vector3(0.06, 0.06, 0.06), Color(0.9, 0.8, 0.3), Vector3(1.15, 1.05, 0.08), Vector3.ZERO, 3, 6)


static func _roof(b: MK.Builder) -> void:
	for s in [-1, 1]:
		b.push(Vector3(0, 0.5, s * 1.05), Vector3(s * -28.0, 0, 0))
		b.box(Vector3(4.4, 0.16, 2.5), WOOD_D.lightened(0.05), Vector3.ZERO)
		for i in 5:
			b.box(Vector3(4.46, 0.05, 0.3), Color(0.5, 0.36, 0.2).lightened(0.04 * (i % 2)), Vector3(0, 0.1, -1.0 + i * 0.5))
		b.pop()
	b.box(Vector3(4.5, 0.18, 0.2), WOOD_D, Vector3(0, 1.0, 0))


static func _campfire(b: MK.Builder) -> void:
	for i in 8:
		var a := TAU * i / 8.0
		b.blob(Vector3(0.18, 0.13, 0.18), STONE.lightened(0.05 * (i % 3)), Vector3(cos(a) * 0.55, 0.1, sin(a) * 0.55), 0.2)
	for i in 3:
		var a2 := i * TAU / 3.0 + 0.3
		b.cyl(0.07, 0.06, 0.8, Color(0.35, 0.22, 0.12), Vector3(0, 0.12, 0), Vector3(70, rad_to_deg(a2), 0), 6)
	b.cyl(0.35, 0.3, 0.06, Color(0.15, 0.1, 0.08), Vector3(0, 0.02, 0), Vector3.ZERO, 8)


static func _chest(b: MK.Builder) -> void:
	b.box(Vector3(1.2, 0.55, 0.75), WOOD, Vector3(0, 0.28, 0))
	b.box(Vector3(1.24, 0.3, 0.79), WOOD_D, Vector3(0, 0.7, 0))
	b.cyl(0.3, 0.3, 1.24, WOOD_D, Vector3(-0.62, 0.78, 0), Vector3(0, 0, -90), 8)
	for sx in [-0.45, 0.45]:
		b.box(Vector3(0.1, 0.9, 0.8), IRON, Vector3(sx, 0.45, 0))
	b.box(Vector3(0.16, 0.2, 0.06), Color(0.9, 0.8, 0.3), Vector3(0, 0.62, 0.4))


static func _shelter(b: MK.Builder) -> void:
	for sx in [-1.7, 1.7]:
		b.cyl(0.1, 0.09, 2.4, WOOD_D, Vector3(sx, 0, -1.6), Vector3.ZERO, 6)
	b.cyl(0.1, 0.09, 1.2, WOOD_D, Vector3(-1.7, 0, 1.5), Vector3.ZERO, 6)
	b.cyl(0.1, 0.09, 1.2, WOOD_D, Vector3(1.7, 0, 1.5), Vector3.ZERO, 6)
	b.push(Vector3(0, 1.8, 0), Vector3(-17, 0, 0))
	b.box(Vector3(4.2, 0.12, 4.4), Color(0.42, 0.55, 0.28))
	for i in 6:
		b.box(Vector3(4.3, 0.1, 0.18), WOOD_D, Vector3(0, 0.1, -2.0 + i * 0.8))
	b.pop()
	b.box(Vector3(3.2, 0.1, 3.0), Color(0.5, 0.42, 0.28), Vector3(0, 0.05, 0))


static func _bedroll(b: MK.Builder) -> void:
	b.box(Vector3(0.9, 0.12, 2.0), Color(0.75, 0.62, 0.42), Vector3(0, 0.06, 0))
	b.cyl(0.24, 0.24, 0.9, Color(0.35, 0.5, 0.62), Vector3(-0.45, 0.24, -0.8), Vector3(0, 0, -90), 8)
	b.box(Vector3(0.7, 0.15, 0.4), Color(0.9, 0.9, 0.85), Vector3(0, 0.18, -0.75))
	b.box(Vector3(0.88, 0.1, 1.1), Color(0.3, 0.45, 0.55), Vector3(0, 0.17, 0.35))


static func _workbench(b: MK.Builder) -> void:
	b.box(Vector3(2.2, 0.16, 1.0), WOOD_L, Vector3(0, 0.95, 0))
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			b.box(Vector3(0.14, 0.95, 0.14), WOOD_D, Vector3(sx * 0.95, 0.47, sz * 0.4))
	b.box(Vector3(2.0, 0.08, 0.8), WOOD_D, Vector3(0, 0.35, 0))
	b.box(Vector3(0.5, 0.1, 0.12), IRON, Vector3(-0.6, 1.08, 0.1), Vector3(0, 20, 0))
	b.cyl(0.04, 0.04, 0.5, WOOD_D, Vector3(0.5, 1.03, 0.1), Vector3(0, 0, 90), 6)
	b.box(Vector3(0.25, 0.2, 0.25), IRON, Vector3(0.75, 1.13, -0.2))


static func _cooking(b: MK.Builder) -> void:
	b.box(Vector3(2.0, 0.8, 1.0), STONE, Vector3(0, 0.4, 0))
	b.box(Vector3(2.1, 0.12, 1.1), STONE.lightened(0.15), Vector3(0, 0.84, 0))
	b.cyl(0.4, 0.34, 0.4, Color(0.25, 0.25, 0.28), Vector3(-0.4, 0.9, 0), Vector3.ZERO, 10)
	b.cyl(0.36, 0.36, 0.04, Color(0.6, 0.35, 0.2), Vector3(-0.4, 1.28, 0), Vector3.ZERO, 10)
	b.box(Vector3(0.7, 0.04, 0.5), WOOD_D, Vector3(0.55, 0.92, 0))
	b.cyl(0.06, 0.06, 1.3, WOOD_D, Vector3(0.9, 0.9, -0.3), Vector3.ZERO, 6)


static func _lamp(b: MK.Builder) -> void:
	b.cyl(0.07, 0.06, 2.4, WOOD_D, Vector3.ZERO, Vector3.ZERO, 6)
	b.box(Vector3(0.4, 0.06, 0.4), IRON, Vector3(0, 2.4, 0))
	b.sphere(Vector3(0.17, 0.26, 0.17), Color(0.55, 0.95, 1.0), Vector3(0, 2.62, 0), Vector3.ZERO, 4, 8)
	b.cone(0.28, 0.2, IRON, Vector3(0, 2.86, 0), Vector3.ZERO, 6)


static func _barricade(b: MK.Builder) -> void:
	for i in 5:
		var x := -1.0 + i * 0.5
		b.cyl(0.11, 0.0, 1.5, WOOD_L, Vector3(x, 0.0, 0.18 * (1 if i % 2 == 0 else -1)), Vector3(0, 0, (i - 2) * 6.0), 5)
	b.cyl(0.07, 0.07, 2.4, WOOD_D, Vector3(-1.2, 0.35, 0), Vector3(0, 0, -90), 6)
	b.cyl(0.07, 0.07, 2.4, WOOD_D, Vector3(-1.2, 0.8, 0), Vector3(0, 0, -90), 6)


static func _turret(b: MK.Builder) -> void:
	b.cyl(0.45, 0.35, 0.3, IRON.darkened(0.2), Vector3.ZERO, Vector3.ZERO, 8)
	b.cyl(0.1, 0.1, 1.0, IRON, Vector3(0, 0.25, 0), Vector3.ZERO, 6)
	b.sphere(Vector3(0.38, 0.3, 0.38), IRON.lightened(0.1), Vector3(0, 1.3, 0), Vector3.ZERO, 5, 8)
	b.cyl(0.07, 0.06, 0.8, Color(0.3, 0.32, 0.36), Vector3(0, 1.3, -0.1), Vector3(-90, 0, 0), 6)
	b.sphere(Vector3(0.1, 0.1, 0.1), Color(0.5, 0.95, 1.0), Vector3(0, 1.3, -0.95), Vector3.ZERO, 3, 6)


static func _processor(b: MK.Builder) -> void:
	b.box(Vector3(1.9, 1.2, 1.7), IRON.darkened(0.15), Vector3(0, 0.6, 0))
	b.box(Vector3(2.0, 0.12, 1.8), IRON, Vector3(0, 1.26, 0))
	b.cyl(0.25, 0.2, 1.0, Color(0.35, 0.36, 0.4), Vector3(0.55, 1.3, 0.3), Vector3.ZERO, 8)
	b.box(Vector3(0.7, 0.5, 0.06), Color(0.15, 0.17, 0.2), Vector3(-0.3, 0.7, 0.88))
	b.box(Vector3(0.5, 0.12, 0.02), Color(0.45, 0.95, 0.8), Vector3(-0.3, 0.78, 0.92))
	b.sphere(Vector3(0.16, 0.2, 0.16), Color(0.55, 0.95, 1.0), Vector3(-0.6, 1.5, -0.3), Vector3.ZERO, 4, 8)
