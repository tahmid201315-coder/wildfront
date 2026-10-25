extends Node3D
## Chunked MultiMesh manager. Instances are queued with add(), then flush() builds one
## MultiMeshInstance3D per (chunk, mesh). Handles allow hiding/showing single instances (felled trees).

const DW = preload("res://scripts/core/data_world.gd")
const Models = preload("res://scripts/gfx/models.gd")

const CHUNK := 64.0

var _pending: Dictionary = {}     # key -> {mesh, xforms[], colors[], range}
var _handles: Array = []          # pending handle objects
var built: Array = []
var vis_scale: float = 1.0


class Handle:
	extends RefCounted
	var mm: MultiMesh
	var idx: int = -1
	var xf: Transform3D
	var key: String
	var pending_i: int = -1
	func set_visible_inst(v: bool) -> void:
		if mm == null or idx < 0:
			return
		mm.set_instance_transform(idx, xf if v else Transform3D(Basis.from_scale(Vector3.ZERO), xf.origin))


func add(kind: String, variant: int, xf: Transform3D, col: Color = Color(1, 1, 1), range_end: float = 0.0, want_handle: bool = false) -> Handle:
	var cx := int(floor((xf.origin.x + DW.WORLD_SIZE * 0.5) / CHUNK))
	var cz := int(floor((xf.origin.z + DW.WORLD_SIZE * 0.5) / CHUNK))
	var key := "%d_%d_%s_%d" % [cx, cz, kind, variant]
	if not _pending.has(key):
		_pending[key] = {"kind": kind, "variant": variant, "xf": [], "col": [], "range": range_end, "cx": cx, "cz": cz, "handles": []}
	var p: Dictionary = _pending[key]
	p["xf"].append(xf)
	p["col"].append(col)
	if want_handle:
		var h := Handle.new()
		h.xf = xf
		h.key = key
		h.pending_i = p["xf"].size() - 1
		p["handles"].append(h)
		return h
	return null


func flush() -> void:
	for key in _pending.keys():
		_build(_pending[key])
	_pending.clear()


func _build(p: Dictionary) -> void:
	var xs: Array = p["xf"]
	if xs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = Models.get_mesh(p["kind"], p["variant"])
	mm.instance_count = xs.size()
	var cols: Array = p["col"]
	var aabb := AABB(xs[0].origin, Vector3.ZERO)
	for i in xs.size():
		mm.set_instance_transform(i, xs[i])
		mm.set_instance_color(i, cols[i])
		aabb = aabb.expand(xs[i].origin)
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.custom_aabb = aabb.grow(14.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var r: float = float(p["range"])
	if r > 0.0:
		mi.visibility_range_end = r * vis_scale
		mi.visibility_range_end_margin = 6.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	add_child(mi)
	built.append(mi)
	for h in p["handles"]:
		h.mm = mm
		h.idx = h.pending_i
