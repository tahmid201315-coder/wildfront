extends Node
## Placement preview, grid snapping, validation, placing and dismantling of structures.

const WG = preload("res://scripts/world/world_gen.gd")
const DW = preload("res://scripts/core/data_world.gd")
const Structure = preload("res://scripts/building/structure.gd")
const StructModels = preload("res://scripts/gfx/struct_models.gd")

const CELL := 4.0
const WALL_H := 3.0

var world: Node3D
var structures: Array = []
var cells: Dictionary = {}            # "cx,cz" -> {found: Structure, upper: Structure}
var edges: Dictionary = {}            # "h,x,z" / "v,x,z" -> Structure
var active: bool = false
var sid: String = ""
var yaw: float = 0.0
var remove_mode: bool = false
var preview: MeshInstance3D = null
var preview_door: MeshInstance3D = null
var valid: bool = false
var reason: String = ""
var _target_pos: Vector3
var _target_yaw: float
var _target_cell: Vector2i
var _target_edge: String = ""
var _remove_target: Structure = null
var _mat_ok: StandardMaterial3D
var _mat_bad: StandardMaterial3D
var _mat_rm: StandardMaterial3D


func _init() -> void:
	_mat_ok = _ghost(Color(0.3, 1.0, 0.45, 0.45))
	_mat_bad = _ghost(Color(1.0, 0.3, 0.25, 0.45))
	_mat_rm = _ghost(Color(1.0, 0.75, 0.2, 0.5))


func _ghost(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func cost_of(id: String) -> Dictionary:
	var c: Dictionary = Data.structures[id]["cost"]
	if Game.has_skill("en1"):
		var out := {}
		for k in c:
			out[k] = maxi(1, int(ceil(float(c[k]) * 0.8)))
		return out
	return c


# ----------------------------------------------------------------- mode control
func begin(structure_id: String) -> void:
	sid = structure_id
	remove_mode = false
	active = true
	yaw = world.player.facing_yaw if Data.structures[sid]["kind"] != "edge" else 0.0
	_make_preview()
	Game.set_state(Game.State.BUILDING)
	Game.toast("Aim, rotate, then confirm.", "info")


func begin_remove() -> void:
	remove_mode = true
	active = true
	sid = ""
	_clear_preview()
	Game.set_state(Game.State.BUILDING)


func cancel() -> void:
	if not active:
		return
	active = false
	_clear_preview()
	_set_highlight(null)
	if Game.state == Game.State.BUILDING:
		Game.set_state(Game.State.PLAY)


func toggle_remove() -> void:
	remove_mode = not remove_mode
	if remove_mode:
		_clear_preview()
	else:
		if sid != "":
			_make_preview()
		else:
			cancel()


func rotate_piece() -> void:
	var k: String = Data.structures[sid]["kind"] if sid != "" else ""
	if k == "edge" or k == "foundation" or k == "roof":
		return
	yaw = fposmod(yaw + PI * 0.25, TAU)
	Sfx.play("click")


func _make_preview() -> void:
	_clear_preview()
	preview = MeshInstance3D.new()
	var mid := sid if sid != "door" else "door_frame"
	preview.mesh = StructModels.get_mesh(mid)
	preview.material_override = _mat_ok
	world.add_child(preview)


func _clear_preview() -> void:
	if preview:
		preview.queue_free()
		preview = null


# ----------------------------------------------------------------- queries
static func ckey(c: Vector2i) -> String:
	return "%d,%d" % [c.x, c.y]


func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(int(floor(p.x / CELL)), int(floor(p.z / CELL)))


func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c.x * CELL + CELL * 0.5, c.y * CELL + CELL * 0.5)


func foundation_top(c: Vector2i) -> float:
	var f: Variant = cells.get(ckey(c), {}).get("found")
	return f.global_position.y if f != null else NAN


func _terrain_range(cx: float, cz: float, half: float) -> Vector2:
	var lo := 1e9
	var hi := -1e9
	for ix in 3:
		for iz in 3:
			var h := WG.height_at(cx + (ix - 1) * half, cz + (iz - 1) * half)
			lo = minf(lo, h)
			hi = maxf(hi, h)
	return Vector2(lo, hi)


func edge_pos(key: String) -> Dictionary:
	var parts := key.split(",")
	var x := int(parts[1])
	var z := int(parts[2])
	if parts[0] == "h":
		return {"pos": Vector2(x * CELL + CELL * 0.5, z * CELL), "yaw": 0.0, "adj": [Vector2i(x, z - 1), Vector2i(x, z)]}
	return {"pos": Vector2(x * CELL, z * CELL + CELL * 0.5), "yaw": PI * 0.5, "adj": [Vector2i(x - 1, z), Vector2i(x, z)]}


func nearest_edge(p: Vector3) -> String:
	var best := ""
	var bd := 1e9
	var c := cell_of(p)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var cc := Vector2i(c.x + dx, c.y + dz)
			for k in ["h,%d,%d" % [cc.x, cc.y], "v,%d,%d" % [cc.x, cc.y]]:
				var ep: Vector2 = edge_pos(k)["pos"]
				var d := Vector2(p.x, p.z).distance_to(ep)
				if d < bd:
					bd = d
					best = k
	return best


# ----------------------------------------------------------------- per-frame
func _process(_delta: float) -> void:
	if not active or world == null or world.player == null:
		return
	var pl: CharacterBody3D = world.player
	var fwd := Vector3(-sin(pl.cam_yaw), 0, -cos(pl.cam_yaw))
	var aim := pl.global_position + fwd * 4.2
	if remove_mode:
		_update_remove(pl)
		return
	var d: Dictionary = Data.structures[sid]
	var kind := String(d["kind"])
	valid = true
	reason = ""
	match kind:
		"free":
			_target_pos = Vector3(aim.x, 0, aim.z)
			_target_yaw = yaw
			var c := cell_of(aim)
			var ft := foundation_top(c)
			var cd: Dictionary = cells.get(ckey(c), {})
			if not is_nan(ft) and cd.has("found"):
				var up: Variant = cd.get("upper")
				_target_pos.y = ft + (0.1 if up == null else 0.0)
				if up != null:
					valid = false
					reason = "Space is taken"
			else:
				_target_pos.y = WG.height_at(aim.x, aim.z)
				var sl := WG.slope_at(aim.x, aim.z)
				if sl > 0.5:
					valid = false
					reason = "Ground is too steep"
		"foundation":
			_target_cell = cell_of(aim)
			var cc := cell_center(_target_cell)
			_target_yaw = 0.0
			var rng := _terrain_range(cc.x, cc.y, CELL * 0.5)
			_target_pos = Vector3(cc.x, rng.y + 0.0, cc.y)
			if cells.has(ckey(_target_cell)) and cells[ckey(_target_cell)].has("found"):
				valid = false
				reason = "A foundation is already here"
			elif rng.y - rng.x > 0.7:
				valid = false
				reason = "Ground is too uneven"
			elif rng.x < 0.6:
				valid = false
				reason = "Too close to water"
		"floor", "roof":
			_target_cell = cell_of(aim)
			var cc2 := cell_center(_target_cell)
			_target_yaw = 0.0
			var cd2: Dictionary = cells.get(ckey(_target_cell), {})
			var ft2 := foundation_top(_target_cell)
			_target_pos = Vector3(cc2.x, (ft2 if not is_nan(ft2) else WG.height_at(cc2.x, cc2.y)) + WALL_H, cc2.y)
			if kind == "floor":
				_target_pos.y += 0.0
			if not cd2.has("found"):
				valid = false
				reason = "Needs a foundation below"
			elif cd2.get("upper") != null:
				valid = false
				reason = "Already covered"
		"edge":
			_target_edge = nearest_edge(aim)
			var ep := edge_pos(_target_edge)
			_target_yaw = float(ep["yaw"])
			var top := NAN
			for ac in ep["adj"]:
				var t := foundation_top(ac)
				if not is_nan(t):
					top = t if is_nan(top) else maxf(top, t)
			var p2: Vector2 = ep["pos"]
			_target_pos = Vector3(p2.x, 0.0 if is_nan(top) else top, p2.y)
			if is_nan(top):
				valid = false
				reason = "Walls need a foundation edge"
			elif edges.has(_target_edge):
				valid = false
				reason = "Edge already built"
	if valid:
		_common_checks(Vector2(_target_pos.x, _target_pos.z), kind, d)
	if valid and not Inv.has_all(cost_of(sid)):
		valid = false
		reason = "Missing materials"
	preview.global_position = _target_pos
	preview.rotation.y = _target_yaw
	preview.material_override = _mat_ok if valid else _mat_bad


func _common_checks(p: Vector2, kind: String, d: Dictionary) -> void:
	if WG.height_at(p.x, p.y) < 0.7 and kind != "roof" and kind != "floor":
		valid = false
		reason = "Too close to water"
		return
	for k in DW.SITES:
		var s: Dictionary = DW.SITES[k]
		if String(s["kind"]) in ["grove_arena", "furnace_arena", "core_facility", "core_gate", "seal_gate", "facility"]:
			if p.distance_to(s["pos"]) < float(s["flat"]) + 4.0:
				valid = false
				reason = "You cannot build here"
				return
	var fp: Vector2 = d["size"]
	var rad := maxf(fp.x, fp.y) * 0.5
	if kind == "free" or kind == "foundation":
		for r in world.resources:
			if not r.depleted and r.global_position.distance_to(Vector3(p.x, r.global_position.y, p.y)) < float(r.def["radius"]) + rad * 0.8:
				valid = false
				reason = "Something is in the way"
				return
		if kind == "free":
			for s in structures:
				if is_instance_valid(s) and s.kind == "free" and Vector2(s.global_position.x, s.global_position.z).distance_to(p) < rad + 0.5 * maxf(s.footprint.x, s.footprint.y) * 0.8 and absf(s.global_position.y - _target_pos.y) < 1.0:
					valid = false
					reason = "Too close to another structure"
					return
	if kind in ["foundation", "free"]:
		var pp := Vector2(world.player.global_position.x, world.player.global_position.z)
		if kind == "foundation" and pp.distance_to(p) < 0.0:
			pass


func _update_remove(pl: Node) -> void:
	var fwd := Vector3(-sin(pl.cam_yaw), 0, -cos(pl.cam_yaw))
	var aim: Vector3 = pl.global_position + fwd * 3.0
	var best: Structure = null
	var bd := 4.0
	for s in structures:
		if not is_instance_valid(s):
			continue
		var d: float = Vector2(s.global_position.x, s.global_position.z).distance_to(Vector2(aim.x, aim.z))
		if d < bd and absf(s.global_position.y - pl.global_position.y) < 5.0:
			bd = d
			best = s
	_set_highlight(best)
	_remove_target = best
	valid = best != null
	reason = "" if valid else "Aim at a structure to dismantle"
	if best != null:
		var why := removal_block(best)
		if why != "":
			valid = false
			reason = why


func _set_highlight(s: Structure) -> void:
	for o in structures:
		if is_instance_valid(o) and o.mesh_inst:
			o.mesh_inst.material_override = null
	if s != null and is_instance_valid(s):
		s.mesh_inst.material_override = _mat_rm


func removal_block(s: Structure) -> String:
	if s.sid == "foundation":
		var cd: Dictionary = cells.get(ckey(s.cell), {})
		if cd.get("upper") != null:
			return "Remove what is above it first"
		for k in edges:
			var ep := edge_pos(k)
			for ac in ep["adj"]:
				if ac == s.cell:
					return "Remove its walls first"
		for o in structures:
			if is_instance_valid(o) and o.kind == "free" and cell_of(o.global_position) == s.cell and absf(o.global_position.y - s.global_position.y) < 0.6:
				return "Remove items on it first"
	if s.sid == "chest" and not s.storage.is_empty():
		return "Empty the box first"
	return ""


# ----------------------------------------------------------------- confirm
func confirm() -> void:
	if not active:
		return
	if remove_mode:
		if valid and _remove_target:
			dismantle(_remove_target)
			_remove_target = null
		else:
			Game.toast(reason, "warn")
			Sfx.play("invalid")
		return
	if not valid:
		Game.toast(reason, "warn")
		Sfx.play("invalid")
		return
	var cost := cost_of(sid)
	if not Inv.has_all(cost):
		return
	for k in cost:
		Inv.remove(k, int(cost[k]))
	var s := place(sid, _target_pos, _target_yaw)
	var kind := String(Data.structures[sid]["kind"])
	match kind:
		"foundation", "floor", "roof":
			s.cell = _target_cell
			var key := ckey(_target_cell)
			if not cells.has(key):
				cells[key] = {}
			if kind == "foundation":
				cells[key]["found"] = s
			else:
				cells[key]["upper"] = s
		"edge":
			s.edge_key = _target_edge
			edges[_target_edge] = s
	Game.add_stat("place:" + sid)
	Game.add_xp(4)
	Sfx.play("place")
	world.spawn_burst(_target_pos + Vector3(0, 0.3, 0), Color(0.75, 0.6, 0.4), 10, 2.5)
	world.update_shelter_flag()


func place(id: String, pos: Vector3, yw: float) -> Structure:
	var s := Structure.new()
	s.position = pos
	world.add_child(s)
	s.setup(id, yw)
	structures.append(s)
	return s


func dismantle(s: Structure) -> void:
	var cost: Dictionary = Data.structures[s.sid]["cost"]
	for k in cost:
		var n := int(floor(float(cost[k]) * 0.7))
		if n > 0:
			Game.give_item(k, n)
	match s.kind:
		"foundation":
			cells.get(ckey(s.cell), {}).erase("found")
		"floor", "roof":
			cells.get(ckey(s.cell), {}).erase("upper")
		"edge":
			edges.erase(s.edge_key)
	structures.erase(s)
	Sfx.play("dismantle")
	world.spawn_burst(s.global_position + Vector3(0, 0.5, 0), Color(0.6, 0.5, 0.35), 10, 3.0)
	s.queue_free()
	_set_highlight(null)
	world.update_shelter_flag()


# ----------------------------------------------------------------- persistence
func serialize() -> Array:
	var out: Array = []
	for s in structures:
		if is_instance_valid(s):
			var d: Dictionary = s.serialize()
			d["cell"] = [s.cell.x, s.cell.y]
			d["edge"] = s.edge_key
			out.append(d)
	return out


func restore(arr: Array) -> void:
	for d in arr:
		var id := String(d.get("sid", ""))
		if not Data.structures.has(id):
			continue
		var s := place(id, Vector3(float(d["x"]), float(d["y"]), float(d["z"])), float(d.get("yaw", 0.0)))
		var kind := String(Data.structures[id]["kind"])
		var cl: Array = d.get("cell", [0, 0])
		s.cell = Vector2i(int(cl[0]), int(cl[1]))
		var key := ckey(s.cell)
		if kind == "foundation" or kind == "floor" or kind == "roof":
			if not cells.has(key):
				cells[key] = {}
			cells[key]["found" if kind == "foundation" else "upper"] = s
		elif kind == "edge":
			s.edge_key = String(d.get("edge", ""))
			edges[s.edge_key] = s
		s.restore_state(d)


## Shelter test for the player's position: roofed cell with foundation and at least 3 blocked sides,
## or standing next to a lean-to shelter.
func is_sheltered(p: Vector3) -> bool:
	for s in structures:
		if is_instance_valid(s) and s.sid == "shelter" and Vector2(s.global_position.x, s.global_position.z).distance_to(Vector2(p.x, p.z)) < 3.0:
			return true
	var c := cell_of(p)
	var cd: Dictionary = cells.get(ckey(c), {})
	if not cd.has("found") or cd.get("upper") == null:
		return false
	if absf(p.y - (cd["found"].global_position.y)) > 3.0:
		return false
	var blocked := 0
	for k in ["h,%d,%d" % [c.x, c.y], "h,%d,%d" % [c.x, c.y + 1], "v,%d,%d" % [c.x, c.y], "v,%d,%d" % [c.x + 1, c.y]]:
		if edges.has(k):
			blocked += 1
	return blocked >= 3
