extends Node3D
## Structure registry + placement mode. Uses a 4 m spatial hash so validation only looks at nearby pieces.

const StructureScript = preload("res://scripts/building/structure.gd")
const MAX_STRUCTURES := 150
const CELL := 4.0
const ROOF_HEIGHT := 3.65

var world: Node = null
var structures: Dictionary = {}      # id -> structure node
var hash_grid: Dictionary = {}       # Vector2i (4 m bucket) -> Array of ids (free pieces, walls, doors)
var cells: Dictionary = {}           # Vector2i grid cell -> {"id": String, "top": float}
var edges: Dictionary = {}           # Vector2i edge key -> id
var roofs: Dictionary = {}           # Vector2i grid cell -> id
var next_id: int = 1

var active: bool = false
var active_kit: String = ""
var active_type: String = ""
var preview: Node3D = null
var rot_y: float = 0.0
var last_result: Dictionary = {}
var _mat_ok: StandardMaterial3D
var _mat_bad: StandardMaterial3D
var _preview_ok_state: int = -1


func _ready() -> void:
	_mat_ok = _ghost_mat(Color(0.3, 1.0, 0.4, 0.5))
	_mat_bad = _ghost_mat(Color(1.0, 0.25, 0.2, 0.5))


func _ghost_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


static func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(roundi(p.x / CELL), roundi(p.z / CELL))


static func bucket_of(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.z / CELL))


func structure_count() -> int:
	return structures.size()


# ------------------------------------------------------------ validation
func _ground_range(center: Vector3, half: float) -> Vector2:
	var lo := INF
	var hi := -INF
	for off in [Vector2(-half, -half), Vector2(half, -half), Vector2(-half, half), Vector2(half, half), Vector2.ZERO]:
		var h: float = world.height_at(center.x + off.x, center.z + off.y)
		lo = minf(lo, h)
		hi = maxf(hi, h)
	return Vector2(lo, hi)


func _nearby_ids(p: Vector3, radius_buckets: int = 1) -> Array:
	var out: Array = []
	var b := bucket_of(p)
	for dz in range(-radius_buckets, radius_buckets + 1):
		for dx in range(-radius_buckets, radius_buckets + 1):
			var k := Vector2i(b.x + dx, b.y + dz)
			if hash_grid.has(k):
				for id in hash_grid[k]:
					if not out.has(id):
						out.append(id)
	return out


func _nearest_cell(raw: Vector3, max_dist: float) -> Vector2i:
	var best := Vector2i(999999, 999999)
	var bd := max_dist
	var c := cell_of(raw)
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			var k := Vector2i(c.x + dx, c.y + dz)
			if cells.has(k):
				var d := Vector2(raw.x - k.x * CELL, raw.z - k.y * CELL).length()
				if d < bd:
					bd = d
					best = k
	return best


func _cell_rect_overlaps_circle(cell: Vector2i, center: Vector3, r: float) -> bool:
	var cx := cell.x * CELL
	var cz := cell.y * CELL
	var nx := clampf(center.x, cx - 2.0, cx + 2.0)
	var nz := clampf(center.z, cz - 2.0, cz + 2.0)
	return Vector2(center.x - nx, center.z - nz).length() < r


func _circle_inside_cell(cell: Vector2i, center: Vector3, r: float) -> bool:
	var cx := cell.x * CELL
	var cz := cell.y * CELL
	return absf(center.x - cx) <= 2.0 - r and absf(center.z - cz) <= 2.0 - r


## Check if `type` can be placed near `raw`. Returns {ok, reason, pos, rot}.
func validate_placement(type: String, raw: Vector3, rot: float) -> Dictionary:
	var res := {"ok": false, "reason": "", "pos": raw, "rot": rot}
	if not Data.buildings.has(type):
		res["reason"] = "Unknown structure"
		return res
	if structures.size() >= MAX_STRUCTURES:
		res["reason"] = "Structure limit reached"
		return res
	if absf(raw.x) > 100.0 or absf(raw.z) > 100.0:
		res["reason"] = "Too close to the edge of the world"
		return res
	var b: Dictionary = Data.buildings[type]
	match b["kind"]:
		"grid":
			var cell := cell_of(raw)
			var center := Vector3(cell.x * CELL, 0, cell.y * CELL)
			var gr := _ground_range(center, 2.0)
			if gr.x < world.WATER_Y + 0.05:
				res["reason"] = "Too close to water"
				return res
			if gr.y - gr.x > 0.8:
				res["reason"] = "Ground is too steep"
				return res
			if cells.has(cell):
				res["reason"] = "Space already used"
				return res
			if world.obstacle_overlap(center, 2.7):
				res["reason"] = "Something is in the way"
				return res
			for id in _nearby_ids(center, 1):
				var s: Node = structures[id]
				if Data.buildings[s.type]["kind"] == "free" and _cell_rect_overlaps_circle(cell, s.position, float(Data.buildings[s.type]["radius"])):
					res["reason"] = "Blocked by furniture"
					return res
			center.y = gr.y + 0.05
			res["pos"] = center
			res["rot"] = 0.0
		"edge":
			var cell2 := _nearest_cell(raw, 4.5)
			if cell2.x == 999999:
				res["reason"] = "Aim at a foundation or floor edge"
				return res
			var cx := cell2.x * CELL
			var cz := cell2.y * CELL
			var dx := raw.x - cx
			var dz := raw.z - cz
			var ex := cx
			var ez := cz
			var er := 0.0
			if absf(dx) >= absf(dz):
				ex += 2.0 * signf(dx) if dx != 0.0 else 2.0
				er = PI * 0.5
			else:
				ez += 2.0 * signf(dz) if dz != 0.0 else 2.0
			var key := Vector2i(roundi(ex * 2.0), roundi(ez * 2.0))
			if edges.has(key):
				res["reason"] = "Edge already has a wall or door"
				return res
			res["pos"] = Vector3(ex, cells[cell2]["top"], ez)
			res["rot"] = er
		"roof":
			var cell3 := _nearest_cell(raw, 3.5)
			if cell3.x == 999999:
				res["reason"] = "Aim at a foundation or floor"
				return res
			if roofs.has(cell3):
				res["reason"] = "Already roofed"
				return res
			res["pos"] = Vector3(cell3.x * CELL, float(cells[cell3]["top"]) + ROOF_HEIGHT, cell3.y * CELL)
			res["rot"] = rot
		_:
			var r: float = float(b["radius"])
			var p := Vector3(snappedf(raw.x, 0.5), 0.0, snappedf(raw.z, 0.5))
			var on_cell := Vector2i(999999, 999999)
			for dz2 in range(-1, 2):
				for dx2 in range(-1, 2):
					var k := Vector2i(cell_of(p).x + dx2, cell_of(p).y + dz2)
					if cells.has(k) and _cell_rect_overlaps_circle(k, p, r):
						if _circle_inside_cell(k, p, r):
							on_cell = k
						else:
							res["reason"] = "Overlaps the edge of a foundation"
							return res
			if on_cell.x != 999999:
				if type == "plot":
					res["reason"] = "Plots need open ground"
					return res
				p.y = cells[on_cell]["top"]
			else:
				var gr2 := _ground_range(p, r)
				if gr2.x < world.WATER_Y + 0.05:
					res["reason"] = "Too close to water"
					return res
				if gr2.y - gr2.x > 0.6:
					res["reason"] = "Ground is too steep"
					return res
				p.y = gr2.y
			if world.obstacle_overlap(p, r + 0.2):
				res["reason"] = "Something is in the way"
				return res
			for id in _nearby_ids(p, 1):
				var s2: Node = structures[id]
				var k2: String = Data.buildings[s2.type]["kind"]
				if k2 == "free":
					if Vector2(s2.position.x - p.x, s2.position.z - p.z).length() < r + float(Data.buildings[s2.type]["radius"]):
						res["reason"] = "Too close to another structure"
						return res
			res["pos"] = p
			res["rot"] = rot
	res["ok"] = true
	return res


# ------------------------------------------------------------ registry
func place_structure(type: String, pos: Vector3, rot: float, state: Dictionary, forced_id: String = "") -> Node3D:
	var id := forced_id
	if id == "":
		id = "s%d" % next_id
	var n := int(id.substr(1)) if id.length() > 1 else 0
	next_id = maxi(next_id, n + 1)
	var s: Node3D = StructureScript.new()
	s.name = id
	world.structures_root.add_child(s)
	s.setup(world, id, type, pos, rot, state)
	structures[id] = s
	_register(s)
	return s


func _register(s: Node3D) -> void:
	var kind: String = Data.buildings[s.type]["kind"]
	match kind:
		"grid":
			cells[cell_of(s.position)] = {"id": s.sid, "top": s.position.y}
		"roof":
			roofs[cell_of(s.position)] = s.sid
		"edge":
			edges[Vector2i(roundi(s.position.x * 2.0), roundi(s.position.z * 2.0))] = s.sid
			_hash_add(s)
		_:
			_hash_add(s)


func _hash_add(s: Node3D) -> void:
	var b := bucket_of(s.position)
	if not hash_grid.has(b):
		hash_grid[b] = []
	hash_grid[b].append(s.sid)


## True if a creature at p would collide with a built structure.
func blocks(p: Vector3, allow_floors: bool) -> bool:
	if structures.is_empty():
		return false
	if not allow_floors and cells.has(cell_of(p)):
		var c: Dictionary = cells[cell_of(p)]
		if absf(p.x - cell_of(p).x * CELL) <= 2.0 and absf(p.z - cell_of(p).y * CELL) <= 2.0:
			return true
	for id in _nearby_ids(p, 1):
		var s: Node = structures[id]
		var kind: String = Data.buildings[s.type]["kind"]
		if kind == "free":
			if Vector2(s.position.x - p.x, s.position.z - p.z).length() < float(Data.buildings[s.type]["radius"]) + 0.2:
				return true
		elif kind == "edge":
			var local: Vector3 = s.to_local(p)
			if absf(local.x) < 2.0 and absf(local.z) < 0.5:
				if s.type == "door" and bool(s.state.get("open", false)):
					continue
				return true
	return false


func has_station_near(station: String, pos: Vector3, radius: float) -> bool:
	for id in structures:
		var s: Node = structures[id]
		if s.type == station and s.global_position.distance_to(pos) <= radius:
			return true
	return false


func shelter_exists() -> bool:
	for k in cells:
		var walls := 0
		var cx: float = k.x * CELL
		var cz: float = k.y * CELL
		for e in [Vector2(cx + 2.0, cz), Vector2(cx - 2.0, cz), Vector2(cx, cz + 2.0), Vector2(cx, cz - 2.0)]:
			if edges.has(Vector2i(roundi(e.x * 2.0), roundi(e.y * 2.0))):
				walls += 1
		if walls >= 3 and roofs.has(k):
			return true
	return false


# ------------------------------------------------------------ placement mode
func start(kit_id: String) -> bool:
	var item: Dictionary = Data.get_item(kit_id)
	if item.is_empty() or str(item.get("build", "")) == "" or Inv.count(kit_id) <= 0:
		return false
	cancel()
	active = true
	active_kit = kit_id
	active_type = item["build"]
	rot_y = 0.0
	preview = StructureScript.new()
	add_child(preview)
	preview.setup(world, "preview", active_type, Vector3.ZERO, 0.0, {}, true)
	_paint_preview(_mat_bad)
	_preview_ok_state = 0
	Game.set_state(Game.State.BUILDING)
	return true


func _paint_preview(m: Material) -> void:
	var stack: Array = [preview]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			n.material_override = m
		if n is OmniLight3D:
			n.visible = false
		for c in n.get_children():
			stack.append(c)


func rotate_preview() -> void:
	rot_y = fposmod(rot_y + PI * 0.5, TAU)
	Sfx.play("click")


func update_preview(player_pos: Vector3, cam_forward: Vector3, cam_pitch: float) -> void:
	if not active or preview == null:
		return
	var f := Vector3(cam_forward.x, 0, cam_forward.z)
	if f.length() < 0.01:
		f = Vector3(0, 0, -1)
	f = f.normalized()
	var dist := clampf(6.5 - cam_pitch * 5.0, 3.0, 11.0)
	var raw := player_pos + f * dist
	last_result = validate_placement(active_type, raw, rot_y)
	var p: Vector3 = last_result["pos"]
	if not last_result["ok"]:
		p.y = world.height_at(p.x, p.z)
	preview.position = p
	preview.rotation.y = last_result["rot"]
	var st: int = 1 if last_result["ok"] else 0
	if st != _preview_ok_state:
		_preview_ok_state = st
		_paint_preview(_mat_ok if st == 1 else _mat_bad)


func status_text() -> String:
	if not active:
		return ""
	if last_result.get("ok", false):
		return "%s: ready to place" % Data.buildings[active_type]["name"]
	return str(last_result.get("reason", ""))


func confirm() -> bool:
	if not active:
		return false
	if not last_result.get("ok", false):
		Sfx.play("invalid")
		Game.toast(str(last_result.get("reason", "Cannot place here")), "warn")
		return false
	# cost is deducted only after the placement is known to be valid
	if not Inv.remove(active_kit, 1):
		Game.toast("You do not have that kit.", "warn")
		cancel()
		return false
	place_structure(active_type, last_result["pos"], last_result["rot"], {})
	Sfx.play("build")
	world.spawn_burst(last_result["pos"] + Vector3(0, 0.5, 0), Color(0.9, 0.8, 0.6), 10)
	Quests.notify_event("place", active_type, 1)
	if shelter_exists():
		Quests.notify_event("build_shelter", "", 1)
	Game.add_xp(5, "build")
	world.save_now(false)
	if Inv.count(active_kit) <= 0:
		cancel()
	return true


func cancel() -> void:
	if preview != null:
		preview.queue_free()
		preview = null
	var was := active
	active = false
	active_kit = ""
	active_type = ""
	last_result = {}
	if was and Game.state == Game.State.BUILDING:
		Game.set_state(Game.State.PLAY)


func serialize() -> Array:
	var out: Array = []
	for id in structures:
		out.append(structures[id].serialize())
	return out


func clear_all() -> void:
	for id in structures:
		structures[id].queue_free()
	structures.clear()
	hash_grid.clear()
	cells.clear()
	edges.clear()
	roofs.clear()
	next_id = 1
