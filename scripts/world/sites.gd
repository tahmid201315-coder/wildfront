extends RefCounted
## Builds landmark sites: scenery meshes with a few colliders, plus the interactables placed at each.

const MK = preload("res://scripts/gfx/mesh_kit.gd")
const WG = preload("res://scripts/world/world_gen.gd")
const DW = preload("res://scripts/core/data_world.gd")
const SO = preload("res://scripts/world/site_objects.gd")

const STONE := Color(0.50, 0.50, 0.46)
const MOSS := Color(0.34, 0.46, 0.28)
const RUST := Color(0.55, 0.34, 0.22)
const METAL := Color(0.36, 0.39, 0.43)
const WOOD := Color(0.48, 0.34, 0.20)
const DARK := Color(0.16, 0.16, 0.19)
const GLOW := Color(0.35, 0.9, 0.85)

var world: Node3D
var pylons: Array = []
var pylon_order: Array = [0, 1, 2]


func build(w: Node3D) -> void:
	world = w
	for id in DW.SITES:
		var s: Dictionary = DW.SITES[id]
		var root := Node3D.new()
		root.name = "Site_" + id
		var p: Vector2 = s["pos"]
		root.position = Vector3(p.x, WG.height_at(p.x, p.y), p.y)
		world.add_child(root)
		var b := MK.Builder.new(hash(id))
		var cols: Array = []     # [size, local pos, yaw]
		var call := Callable(self, "_k_" + String(s["kind"]))
		if call.is_valid():
			call.call(id, root, b, cols)
		if b.vertex_count() > 0:
			var mi := MeshInstance3D.new()
			mi.mesh = b.commit(MK.style_material(0.0, 0.2, 0.0))
			root.add_child(mi)
		for c in cols:
			SiteUtil.solid(root, c[0], c[1], c[2])


# ------------------------------------------------------------------ helpers
func _at(root: Node3D, local: Vector3) -> Vector3:
	var g := root.global_position + local
	return Vector3(local.x, WG.height_at(g.x, g.z) - root.global_position.y + local.y, local.z)


func _wall(b, cols: Array, pos: Vector3, size: Vector3, col: Color, yaw: float = 0.0, collide: bool = true) -> void:
	b.push(pos, Vector3(0, yaw, 0))
	b.box(size, col, Vector3(0, size.y * 0.5, 0))
	b.pop()
	if collide:
		cols.append([size, pos + Vector3(0, size.y * 0.5, 0), deg_to_rad(yaw)])


func _ring_pillars(b, cols: Array, radius: float, n: int, h: float, col: Color, broken: bool = true) -> void:
	for i in n:
		var a := TAU * i / n
		var hh := h * (0.5 + 0.5 * float((i * 7) % 5) / 4.0 if broken else 1.0)
		var pos := Vector3(cos(a) * radius, 0, sin(a) * radius)
		b.cyl(0.6, 0.5, hh, col, pos, Vector3.ZERO, 7)
		cols.append([Vector3(1.1, hh, 1.1), pos + Vector3(0, hh * 0.5, 0), 0.0])


func _put(root: Node3D, node: Node3D, local: Vector3, yaw: float = 0.0) -> void:
	root.add_child(node)
	node.position = _at(root, local)
	node.rotation.y = deg_to_rad(yaw)


func _crate(root: Node3D, cid: String, table: String, group: String, style: String, local: Vector3, yaw: float = 0.0, fixed: Dictionary = {}) -> void:
	var c = SO.LootContainer.new()
	_put(root, c, local, yaw)
	c.setup(cid, table, group, style, fixed)


func _log(root: Node3D, log_id: String, style: String, local: Vector3, yaw: float = 0.0) -> void:
	var t = SO.LogTerminal.new()
	_put(root, t, local, yaw)
	t.setup(log_id, style)


func _light(root: Node3D, col: Color, local: Vector3, energy: float = 0.8, rng_m: float = 8.0) -> void:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng_m
	l.position = local
	root.add_child(l)


func _rubble(b, n: int, radius: float, col: Color) -> void:
	for i in n:
		var a := float(i) * 2.399
		var r := radius * sqrt(float(i + 1) / n)
		b.blob(Vector3(0.5, 0.35, 0.5) * (0.6 + 0.3 * float(i % 3)), col, Vector3(cos(a) * r, 0.1, sin(a) * r), 0.25, 1)


# ------------------------------------------------------------------ kinds
func _k_crash(id, root, b, cols) -> void:
	b.push(Vector3(0, 0.5, 0), Vector3(8, 25, 6))
	b.box(Vector3(9, 2.6, 3.4), METAL, Vector3(0, 1.3, 0))
	b.box(Vector3(3, 2.0, 3.2), Color(0.28, 0.3, 0.34), Vector3(-5.5, 1.1, 0), Vector3(0, 0, 12))
	b.pop()
	b.push(Vector3(5, 0.5, -3), Vector3(0, 40, 20))
	b.box(Vector3(6, 0.25, 2.4), RUST, Vector3(0, 1, 0))
	b.pop()
	_rubble(b, 14, 10.0, METAL)
	cols.append([Vector3(9, 2.6, 3.4), Vector3(0, 1.5, 0), deg_to_rad(25)])
	_log(root, "log_crash", "terminal", Vector3(3.5, 0, 3.5), 200)
	_crate(root, "crash_crate1", "supply", "supply", "crate", Vector3(-4, 0, 5))
	_crate(root, "crash_crate2", "supply", "supply", "crate", Vector3(-6, 0, 3), 20)


func _k_campsite(id, root, b, cols) -> void:
	b.cone(1.6, 1.8, Color(0.62, 0.52, 0.34), Vector3(-2, 0, 0), Vector3.ZERO, 5)
	b.box(Vector3(2.2, 0.08, 1.6), Color(0.5, 0.4, 0.28), Vector3(2, 0.05, 1))
	for i in 4:
		b.cyl(0.18, 0.18, 0.5, WOOD, Vector3(1.0 + cos(i * 1.57) * 0.7, 0, -1 + sin(i * 1.57) * 0.7), Vector3(80, 0, 0), 5)
	_log(root, "log_camp", "journal", Vector3(0.5, 0, 2.5))
	_crate(root, "camp_crate", "supply", "supply", "crate", Vector3(-4, 0, 3), 40)


func _k_beacon(id, root, b, cols) -> void:
	b.cyl(2.2, 1.4, 10.0, STONE, Vector3.ZERO, Vector3.ZERO, 8)
	b.cyl(1.6, 1.6, 0.8, METAL, Vector3(0, 10, 0), Vector3.ZERO, 8)
	b.box(Vector3(1.4, 0.6, 1.4), Color(0.85, 0.35, 0.3), Vector3(0, 10.9, 0))
	cols.append([Vector3(3.6, 10, 3.6), Vector3(0, 5, 0), 0.0])
	_rubble(b, 8, 6.0, STONE)
	_log(root, "log_coast", "terminal", Vector3(3.8, 0, 0), 90)
	_light(root, Color(1, 0.4, 0.3), Vector3(0, 11, 0), 1.2, 14.0)


func _k_cave(id, root, b, cols) -> void:
	b.blob(Vector3(5.5, 3.6, 4.5), Color(0.38, 0.37, 0.36), Vector3(0, 1.2, 1.0), 0.2, 2)
	b.box(Vector3(2.4, 2.8, 1.0), Color(0.04, 0.04, 0.05), Vector3(0, 1.4, -2.9))
	b.blob(Vector3(1.6, 1.2, 1.3), Color(0.42, 0.4, 0.38), Vector3(-2.2, 0.6, -3), 0.2, 1)
	b.blob(Vector3(1.6, 1.4, 1.3), Color(0.42, 0.4, 0.38), Vector3(2.2, 0.7, -3), 0.2, 1)
	_light(root, Color(0.4, 0.8, 1.0), Vector3(0, 1.4, -2.0), 0.6, 6.0)
	var tbl := "cache" if id != "coast_cave" else ""
	if id == "coast_cave":
		var n = SO.Survivor.new()
		_put(root, n, Vector3(0, 0, -1.8), 0)
		n.setup()
		_crate(root, "coast_cave_crate", "supply", "supply", "crate", Vector3(2.0, 0, -1.4), -30)
	else:
		_crate(root, id + "_cache", "cache", "", "cache", Vector3(0, 0, -1.6))


func _k_arch(id, root, b, cols) -> void:
	b.box(Vector3(1.4, 6.0, 1.4), STONE, Vector3(-3.2, 3.0, 0))
	b.box(Vector3(1.4, 6.0, 1.4), STONE, Vector3(3.2, 3.0, 0))
	b.box(Vector3(8.4, 1.3, 1.5), STONE, Vector3(0, 6.3, 0))
	b.blob(Vector3(5.0, 0.7, 1.0), MOSS, Vector3(0, 7.0, 0), 0.2, 1)
	cols.append([Vector3(1.4, 6, 1.4), Vector3(-3.2, 3, 0), 0.0])
	cols.append([Vector3(1.4, 6, 1.4), Vector3(3.2, 3, 0), 0.0])


func _k_outpost(id, root, b, cols) -> void:
	_wall(b, cols, Vector3(0, 0, -6), Vector3(12, 3.2, 0.6), Color(0.46, 0.5, 0.46), 0)
	_wall(b, cols, Vector3(-6, 0, 0), Vector3(0.6, 3.2, 12), Color(0.46, 0.5, 0.46), 0)
	_wall(b, cols, Vector3(6, 0, 0), Vector3(0.6, 3.2, 12), Color(0.46, 0.5, 0.46), 0)
	_wall(b, cols, Vector3(-3.5, 0, 6), Vector3(5, 3.2, 0.6), Color(0.46, 0.5, 0.46), 0)
	b.box(Vector3(12.6, 0.3, 12.6), Color(0.3, 0.38, 0.3), Vector3(0, 3.4, 0))
	_log(root, "log_outpost1", "terminal", Vector3(-4.5, 0, -4.5), 0)
	_log(root, "log_outpost2", "terminal", Vector3(4.5, 0, -4.5), 0)
	_crate(root, "outpost_locker", "locker", "outpost_locker", "locker", Vector3(0, 0, -5.2), 0, {"survey_kit": 1})
	_crate(root, "outpost_cache", "cache", "", "cache", Vector3(4.5, 0, 3), 90)
	_light(root, Color(0.6, 1, 0.8), Vector3(0, 2.8, 0), 0.7, 9.0)


func _k_ruins(id, root, b, cols) -> void:
	_ring_pillars(b, cols, 8.0, 9, 5.5, Color(0.5, 0.52, 0.44))
	b.box(Vector3(3, 0.6, 3), STONE, Vector3(0, 0.3, 0))
	_wall(b, cols, Vector3(0, 0, -5), Vector3(3, 1.8, 3), Color(0.42, 0.46, 0.4), 0)
	_rubble(b, 12, 8.0, MOSS)
	_log(root, "log_ruins", "stone", Vector3(0, 0, 2.5), 180)
	_crate(root, "ruins_treasure", "treasure", "", "treasure", Vector3(-3, 0, -1.5), 25)


func _k_mushrooms(id, root, b, cols) -> void:
	for i in 14:
		var a := float(i) * 2.4
		var r := 1.5 + float(i % 5) * 1.2
		var h := 0.6 + float(i % 4) * 0.5
		var pos := Vector3(cos(a) * r, 0, sin(a) * r)
		b.cyl(0.14, 0.1, h, Color(0.82, 0.8, 0.7), pos, Vector3.ZERO, 6)
		b.sphere(Vector3(0.5, 0.28, 0.5), Color(0.35, 0.85, 0.8) if i % 2 == 0 else Color(0.5, 0.45, 0.9), pos + Vector3(0, h, 0), Vector3.ZERO, 3, 8)
	_light(root, Color(0.4, 0.9, 0.8), Vector3(0, 1.2, 0), 0.8, 8.0)
	_log(root, "log_shroom", "journal", Vector3(3.5, 0, 3), 200)


func _k_grove_arena(id, root, b, cols) -> void:
	_ring_pillars(b, cols, 24.0, 16, 7.0, Color(0.42, 0.4, 0.34), false)
	b.blob(Vector3(3.0, 0.5, 3.0), Color(0.3, 0.45, 0.28), Vector3(0, 0.1, 0), 0.2, 1)
	_light(root, Color(0.5, 1.0, 0.6), Vector3(0, 2, 0), 0.5, 18.0)


func _k_elder_oak(id, root, b, cols) -> void:
	b.cyl(2.2, 1.4, 14.0, Color(0.38, 0.28, 0.18), Vector3.ZERO, Vector3.ZERO, 9)
	b.blob(Vector3(9.0, 5.0, 9.0), Color(0.22, 0.42, 0.2), Vector3(0, 15.5, 0), 0.3, 2)
	b.blob(Vector3(6.0, 3.5, 6.0), Color(0.26, 0.48, 0.22), Vector3(4, 13.5, 2), 0.3, 1)
	cols.append([Vector3(3.6, 14, 3.6), Vector3(0, 7, 0), 0.0])
	_crate(root, "oak_cache", "treasure", "", "treasure", Vector3(3.2, 0, 2.4), 30)


func _k_facility(id, root, b, cols) -> void:
	_wall(b, cols, Vector3(0, 0, -10), Vector3(20, 6.5, 1.0), Color(0.42, 0.45, 0.5), 0)
	_wall(b, cols, Vector3(-10, 0, -2), Vector3(1.0, 6.5, 16), Color(0.42, 0.45, 0.5), 0)
	_wall(b, cols, Vector3(10, 0, -2), Vector3(1.0, 6.5, 16), Color(0.42, 0.45, 0.5), 0)
	b.box(Vector3(21, 0.6, 17), Color(0.28, 0.3, 0.34), Vector3(0, 6.8, -2))
	_wall(b, cols, Vector3(-6.5, 0, 6.5), Vector3(7, 6.5, 1.0), Color(0.42, 0.45, 0.5), 0)
	_wall(b, cols, Vector3(6.5, 0, 6.5), Vector3(7, 6.5, 1.0), Color(0.42, 0.45, 0.5), 0)
	var gen = SO.Generator.new()
	_put(root, gen, Vector3(0, 0, -7), 0)
	gen.setup()
	_log(root, "log_facility", "terminal", Vector3(-7, 0, -7.5), 0)
	_log(root, "log_suit", "terminal", Vector3(7, 0, -7.5), 0)
	_crate(root, "facility_locker", "locker", "", "locker", Vector3(-8.5, 0, 0), 90)
	_crate(root, "facility_cache", "cache", "", "cache", Vector3(8.0, 0, 0), -90)
	_light(root, Color(0.8, 0.95, 1.0), Vector3(0, 5, -2), 0.8, 14.0)
	world.metal_zones.append([Vector2(root.position.x, root.position.z), 12.0])


func _k_mine(id, root, b, cols) -> void:
	b.box(Vector3(0.5, 3.6, 0.5), WOOD, Vector3(-2, 1.8, 0))
	b.box(Vector3(0.5, 3.6, 0.5), WOOD, Vector3(2, 1.8, 0))
	b.box(Vector3(4.8, 0.5, 0.6), WOOD, Vector3(0, 3.7, 0))
	b.box(Vector3(3.5, 3.0, 0.4), Color(0.03, 0.03, 0.04), Vector3(0, 1.5, -0.3))
	b.blob(Vector3(7, 4.5, 4.5), Color(0.4, 0.38, 0.36), Vector3(0, 2.0, -3.5), 0.2, 2)
	b.box(Vector3(1.6, 0.8, 1.0), RUST, Vector3(4, 0.4, 3))
	_log(root, "log_mine", "journal", Vector3(-3.5, 0, 2.5), 160)
	_crate(root, "mine_locker", "locker", "mine_locker", "locker", Vector3(0, 0, -1.2), 0, {"power_cell": 1})
	_light(root, Color(1, 0.7, 0.4), Vector3(0, 2.8, 0.5), 0.8, 8.0)


func _k_spire(id, root, b, cols) -> void:
	b.cyl(1.6, 0.5, 22.0, METAL, Vector3.ZERO, Vector3.ZERO, 6)
	b.sphere(Vector3(1.0, 1.0, 1.0), Color(0.4, 0.9, 1.0), Vector3(0, 22.5, 0), Vector3.ZERO, 4, 8)
	cols.append([Vector3(3, 20, 3), Vector3(0, 10, 0), 0.0])
	_log(root, "log_spire", "terminal", Vector3(3.2, 0, 0), 90)
	_crate(root, "spire_cache", "cache", "", "cache", Vector3(-3.5, 0, 2.5), 20)
	_light(root, Color(0.4, 0.9, 1.0), Vector3(0, 22, 0), 1.0, 16.0)


func _k_seal_gate(id, root, b, cols) -> void:
	b.box(Vector3(3, 10, 3), STONE, Vector3(-6.5, 5, 0))
	b.box(Vector3(3, 10, 3), STONE, Vector3(6.5, 5, 0))
	b.box(Vector3(16, 3, 3), STONE, Vector3(0, 11.5, 0))
	cols.append([Vector3(3, 10, 3), Vector3(-6.5, 5, 0), 0.0])
	cols.append([Vector3(3, 10, 3), Vector3(6.5, 5, 0), 0.0])
	var g = SO.Gate.new()
	_put(root, g, Vector3(0, 0, 0), 0)
	g.setup("verdant_gate", "verdant_seal", 10.0, Color(0.34, 0.46, 0.36))


func _k_machinery(id, root, b, cols) -> void:
	b.cyl(2.4, 2.0, 7.0, RUST, Vector3(-4, 0, 0), Vector3.ZERO, 8)
	b.box(Vector3(10, 1.2, 1.2), METAL, Vector3(2, 5.0, 0))
	b.cyl(1.2, 1.2, 5.0, METAL, Vector3(5, 0, 3), Vector3.ZERO, 8)
	cols.append([Vector3(4.6, 7, 4.6), Vector3(-4, 3.5, 0), 0.0])
	cols.append([Vector3(2.4, 5, 2.4), Vector3(5, 2.5, 3), 0.0])
	_rubble(b, 12, 9.0, DARK)
	_log(root, "log_foundry", "terminal", Vector3(0, 0, 4.5), 180)
	_crate(root, "foundry_cache", "cache", "", "cache", Vector3(-1, 0, -4), 10)
	world.metal_zones.append([Vector2(root.position.x, root.position.z), 12.0])


func _k_furnace_arena(id, root, b, cols) -> void:
	_ring_pillars(b, cols, 28.0, 14, 9.0, Color(0.22, 0.2, 0.2), false)
	b.cyl(5.0, 4.0, 1.0, Color(0.15, 0.12, 0.12), Vector3.ZERO, Vector3.ZERO, 12)
	_light(root, Color(1.0, 0.45, 0.2), Vector3(0, 3, 0), 1.2, 24.0)


func _k_station(id, root, b, cols) -> void:
	_wall(b, cols, Vector3(0, 0, -5), Vector3(11, 4.0, 0.6), Color(0.28, 0.28, 0.32), 0)
	_wall(b, cols, Vector3(-5.5, 0, 0), Vector3(0.6, 4.0, 10), Color(0.28, 0.28, 0.32), 0)
	_wall(b, cols, Vector3(5.5, 0, 0), Vector3(0.6, 4.0, 10), Color(0.28, 0.28, 0.32), 0)
	b.box(Vector3(11.6, 0.4, 10.6), Color(0.2, 0.2, 0.24), Vector3(0, 4.2, 0))
	_log(root, "log_station", "terminal", Vector3(0, 0, -4.2), 0)
	_crate(root, "station_locker", "locker", "", "locker", Vector3(-4.5, 0, 0), 90)
	_crate(root, "station_cache", "cache", "", "cache", Vector3(4, 0, 2), -60)
	_light(root, Color(1, 0.6, 0.4), Vector3(0, 3, 0), 0.7, 9.0)


func _k_vents(id, root, b, cols) -> void:
	for i in 5:
		var a := float(i) * 1.26
		b.cone(0.9, 1.4, Color(0.16, 0.14, 0.14), Vector3(cos(a) * 5.0, 0, sin(a) * 5.0), Vector3.ZERO, 7)
	_crate(root, "vents_cache", "cache", "", "cache", Vector3(0, 0, 0))
	world.warm_sources.append([root.global_position, 12.0, 6.0, null])


func _k_core_gate(id, root, b, cols) -> void:
	b.box(Vector3(3, 12, 3), Color(0.22, 0.24, 0.3), Vector3(-6.5, 6, 0))
	b.box(Vector3(3, 12, 3), Color(0.22, 0.24, 0.3), Vector3(6.5, 6, 0))
	b.box(Vector3(16, 3, 3), Color(0.22, 0.24, 0.3), Vector3(0, 13.5, 0))
	cols.append([Vector3(3, 12, 3), Vector3(-6.5, 6, 0), 0.0])
	cols.append([Vector3(3, 12, 3), Vector3(6.5, 6, 0), 0.0])
	var g = SO.Gate.new()
	_put(root, g, Vector3(0, 0, 0), 0)
	g.setup("core_gate", "core_key", 10.0, Color(0.26, 0.3, 0.38), true)
	_log(root, "log_gate", "stone", Vector3(0, 0, 5.5), 180)
	var spots := [Vector3(-14, 0, 12), Vector3(0, 0, 18), Vector3(14, 0, 12)]
	for i in 3:
		var py = SO.Pylon.new()
		_put(root, py, spots[i], 0)
		py.setup(i)
		pylons.append(py)


func _k_core_facility(id, root, b, cols) -> void:
	_ring_pillars(b, cols, 30.0, 12, 12.0, Color(0.24, 0.27, 0.34), false)
	b.cyl(6.0, 5.0, 1.2, Color(0.2, 0.22, 0.28), Vector3.ZERO, Vector3.ZERO, 14)
	b.cyl(1.4, 1.0, 9.0, Color(0.3, 0.34, 0.42), Vector3(0, 1.2, 0), Vector3.ZERO, 8)
	b.sphere(Vector3(1.6, 1.6, 1.6), Color(0.4, 0.9, 1.0), Vector3(0, 11.0, 0), Vector3.ZERO, 5, 10)
	_light(root, Color(0.4, 0.9, 1.0), Vector3(0, 10, 0), 1.4, 30.0)
	_log(root, "log_architect", "terminal", Vector3(0, 0, 10), 180)
	_crate(root, "core_cache1", "treasure", "", "treasure", Vector3(-16, 0, 8), 30)
	_crate(root, "core_cache2", "cache", "", "cache", Vector3(16, 0, 8), -30)
