extends Node3D
## Builds terrain chunk meshes + height-map collision from the baked WorldGen grid.

const WG = preload("res://scripts/world/world_gen.gd")
const DW = preload("res://scripts/core/data_world.gd")
const TERRAIN_SHADER := preload("res://shaders/terrain.gdshader")
const WATER_SHADER := preload("res://shaders/water.gdshader")

var material: ShaderMaterial
var chunks: Array = []


func _ready() -> void:
	material = ShaderMaterial.new()
	material.shader = TERRAIN_SHADER


## Creates one chunk per call so loading can show progress. Returns true while more remain.
func build_all_blocking() -> void:
	var cn := DW.GRID_N / DW.CHUNK_CELLS
	for cz in cn:
		for cx in cn:
			build_chunk(cx, cz)


func build_chunk(cx: int, cz: int) -> void:
	var cc := DW.CHUNK_CELLS
	var w := DW.GRID_N + 1
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var heights := PackedFloat32Array()
	var origin_x := -WG.half + cx * cc * DW.CELL
	var origin_z := -WG.half + cz * cc * DW.CELL
	var center := Vector3(origin_x + cc * DW.CELL * 0.5, 0.0, origin_z + cc * DW.CELL * 0.5)
	for lz in cc + 1:
		for lx in cc + 1:
			var gx := cx * cc + lx
			var gz := cz * cc + lz
			var gi := gz * w + gx
			var h := WG.grid[gi]
			verts.append(Vector3(lx * DW.CELL - cc * DW.CELL * 0.5, h, lz * DW.CELL - cc * DW.CELL * 0.5))
			norms.append(WG.normals[gi])
			cols.append(WG.colors[gi])
			heights.append(h)
	var vw := cc + 1
	for lz in cc:
		for lx in cc:
			var i00 := lz * vw + lx
			var i10 := i00 + 1
			var i01 := i00 + vw
			var i11 := i01 + 1
			# clockwise when viewed from above (Godot front-face winding); diagonal 00-11
			idx.append(i00); idx.append(i10); idx.append(i11)
			idx.append(i00); idx.append(i11); idx.append(i01)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.surface_set_material(0, material)
	var body := StaticBody3D.new()
	body.position = center
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.custom_aabb = AABB(Vector3(-cc * DW.CELL * 0.5, -20, -cc * DW.CELL * 0.5), Vector3(cc * DW.CELL, 140, cc * DW.CELL))
	body.add_child(mi)
	var shape := HeightMapShape3D.new()
	shape.map_width = vw
	shape.map_depth = vw
	shape.map_data = heights
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.scale = Vector3(DW.CELL, 1.0, DW.CELL)
	body.add_child(cs)
	chunks.append(body)


func build_water() -> MeshInstance3D:
	var cells := 224
	var span := cells * DW.CELL
	var origin := -span * 0.5
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	var depth := PackedFloat32Array()
	var vw := cells + 1
	depth.resize(vw * vw)
	for iz in vw:
		for ix in vw:
			var x := origin + ix * DW.CELL
			var z := origin + iz * DW.CELL
			var d := -WG.height_at(x, z)
			depth[iz * vw + ix] = d
			verts.append(Vector3(x, 0.0, z))
			norms.append(Vector3.UP)
			var shallow := 1.0 - smoothstep(0.0, 7.0, d)
			var foam := 1.0 - smoothstep(0.0, 1.1, absf(d - 0.25))
			cols.append(Color(shallow, foam, 0.0, 1.0))
	for iz in cells:
		for ix in cells:
			var i00 := iz * vw + ix
			var i10 := i00 + 1
			var i01 := i00 + vw
			var i11 := i01 + 1
			var mx := maxf(maxf(depth[i00], depth[i10]), maxf(depth[i01], depth[i11]))
			if mx < -1.2:
				continue
			idx.append(i00); idx.append(i10); idx.append(i11)
			idx.append(i00); idx.append(i11); idx.append(i01)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var wm := ShaderMaterial.new()
	wm.shader = WATER_SHADER
	mesh.surface_set_material(0, wm)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.name = "Water"
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(origin, -5, origin), Vector3(span, 10, span))
	add_child(mi)
	# distant open ocean
	var far := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(6000, 6000)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.03, 0.2, 0.32)
	fm.roughness = 0.2
	pm.material = fm
	far.mesh = pm
	far.position = Vector3(0, -0.35, 0)
	far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(far)
	return mi
