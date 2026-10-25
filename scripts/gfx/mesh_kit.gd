extends RefCounted
## Procedural mesh toolkit. A Builder accumulates coloured geometry (many primitives) into ONE
## ArrayMesh so each model costs a single draw call. Vertex colour RGB = albedo, A = wind sway weight.

const SHADER_STYLE := preload("res://shaders/stylized.gdshader")

static var _mat_cache: Dictionary = {}


static func style_material(sway: float = 0.0, rim: float = 0.25, emissive_boost: float = 0.0) -> ShaderMaterial:
	var key := "%s_%s_%s" % [sway, rim, emissive_boost]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := ShaderMaterial.new()
	m.shader = SHADER_STYLE
	m.set_shader_parameter("sway_strength", sway)
	m.set_shader_parameter("rim_strength", rim)
	m.set_shader_parameter("emission_boost", emissive_boost)
	_mat_cache[key] = m
	return m


class Builder:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var xf := Transform3D.IDENTITY
	var _stack: Array = []
	var rng := RandomNumberGenerator.new()
	var jitter: float = 0.06       # per-vertex brightness variation (painterly look)
	var ao: float = 0.35           # darkening toward the bottom of each primitive (fake ambient occlusion)
	var sway: float = 0.0          # alpha written to vertices (wind weight), scaled by height when sway_by_height

	func _init(seed_value: int = 1) -> void:
		rng.seed = seed_value

	func push(pos: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> void:
		_stack.append(xf)
		var b := Basis.from_euler(Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z)))
		b = b.scaled(scl)
		xf = xf * Transform3D(b, pos)

	func pop() -> void:
		xf = _stack.pop_back()

	func _col(c: Color, h01: float, wind: float) -> Color:
		var k := 1.0 + rng.randf_range(-jitter, jitter) - ao * (1.0 - clampf(h01, 0.0, 1.0))
		return Color(clampf(c.r * k, 0.0, 1.5), clampf(c.g * k, 0.0, 1.5), clampf(c.b * k, 0.0, 1.5), clampf(wind, 0.0, 1.0))

	func _v(p: Vector3, n: Vector3, c: Color) -> int:
		verts.append(xf * p)
		norms.append((xf.basis * n).normalized())
		cols.append(c)
		return verts.size() - 1

	func tri(a: int, b: int, c: int) -> void:
		idx.append(a); idx.append(b); idx.append(c)

	func quad_idx(a: int, b: int, c: int, d: int) -> void:
		tri(a, b, c); tri(a, c, d)

	# ----------------------------------------------------------------- primitives
	func box(size: Vector3, color: Color, pos: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO, wind: float = 0.0) -> void:
		push(pos, rot_deg)
		var h := size * 0.5
		var faces := [
			[Vector3(0, 0, 1), Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)],
			[Vector3(0, 0, -1), Vector3(h.x, -h.y, -h.z), Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z)],
			[Vector3(1, 0, 0), Vector3(h.x, -h.y, h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z)],
			[Vector3(-1, 0, 0), Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, -h.y, h.z), Vector3(-h.x, h.y, h.z), Vector3(-h.x, h.y, -h.z)],
			[Vector3(0, 1, 0), Vector3(-h.x, h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z)],
			[Vector3(0, -1, 0), Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z)],
		]
		for f in faces:
			var n: Vector3 = f[0]
			var ids: Array = []
			for i in 4:
				var p: Vector3 = f[i + 1]
				ids.append(_v(p, n, _col(color, (p.y + h.y) / maxf(size.y, 0.001), wind)))
			quad_idx(ids[0], ids[1], ids[2], ids[3])
		pop()

	## Tapered cylinder along +Y from y=0 to y=h. top radius 0 makes a cone.
	func cyl(r_bottom: float, r_top: float, h: float, color: Color, pos: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO,
			sides: int = 8, caps: bool = true, wind: float = 0.0, smooth: bool = true) -> void:
		push(pos, rot_deg)
		var slope := (r_bottom - r_top) / maxf(h, 0.001)
		var ring_b: Array = []
		var ring_t: Array = []
		for i in sides + 1:
			var a := TAU * i / sides
			var dir := Vector3(cos(a), 0, sin(a))
			var n := (dir + Vector3(0, slope, 0)).normalized()
			if not smooth:
				var a2 := TAU * (i + 0.5) / sides
				n = (Vector3(cos(a2), slope, sin(a2))).normalized()
			ring_b.append(_v(dir * r_bottom, n, _col(color, 0.0, 0.0)))
			ring_t.append(_v(dir * r_top + Vector3(0, h, 0), n, _col(color, 1.0, wind)))
		for i in sides:
			quad_idx(ring_b[i], ring_t[i], ring_t[i + 1], ring_b[i + 1])
		if caps:
			if r_top > 0.001:
				var c := _v(Vector3(0, h, 0), Vector3.UP, _col(color, 1.0, wind))
				var rim: Array = []
				for i in sides + 1:
					var a := TAU * i / sides
					rim.append(_v(Vector3(cos(a) * r_top, h, sin(a) * r_top), Vector3.UP, _col(color, 1.0, wind)))
				for i in sides:
					tri(c, rim[i + 1], rim[i])
			if r_bottom > 0.001:
				var c2 := _v(Vector3.ZERO, Vector3.DOWN, _col(color, 0.0, 0.0))
				var rim2: Array = []
				for i in sides + 1:
					var a := TAU * i / sides
					rim2.append(_v(Vector3(cos(a) * r_bottom, 0, sin(a) * r_bottom), Vector3.DOWN, _col(color, 0.0, 0.0)))
				for i in sides:
					tri(c2, rim2[i], rim2[i + 1])
		pop()

	func cone(r: float, h: float, color: Color, pos: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO, sides: int = 8, wind: float = 0.0) -> void:
		cyl(r, 0.0, h, color, pos, rot_deg, sides, true, wind)

	## Ellipsoid, smooth shaded.
	func sphere(radii: Vector3, color: Color, pos: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO, rings: int = 6, segs: int = 10, wind: float = 0.0) -> void:
		push(pos, rot_deg)
		var grid: Array = []
		for r in rings + 1:
			var pol := PI * r / rings
			var row: Array = []
			for s in segs + 1:
				var az := TAU * s / segs
				var d := Vector3(sin(pol) * cos(az), cos(pol), sin(pol) * sin(az))
				var p := Vector3(d.x * radii.x, d.y * radii.y, d.z * radii.z)
				var n := Vector3(d.x / maxf(radii.x, 0.001), d.y / maxf(radii.y, 0.001), d.z / maxf(radii.z, 0.001)).normalized()
				row.append(_v(p, n, _col(color, (d.y + 1.0) * 0.5, wind * (d.y + 1.0) * 0.5)))
			grid.append(row)
		for r in rings:
			for s in segs:
				quad_idx(grid[r][s], grid[r + 1][s], grid[r + 1][s + 1], grid[r][s + 1])
		pop()

	## Flat-shaded displaced icosphere: rocks, canopy clumps, crystals' bases.
	func blob(radius: Vector3, color: Color, pos: Vector3 = Vector3.ZERO, rough: float = 0.25, subdiv: int = 1, rot_deg: Vector3 = Vector3.ZERO, wind: float = 0.0, color2: Color = Color(0, 0, 0, 0)) -> void:
		push(pos, rot_deg)
		var t := (1.0 + sqrt(5.0)) / 2.0
		var vs: Array = [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
			Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
			Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
		for i in vs.size():
			vs[i] = (vs[i] as Vector3).normalized()
		var fs: Array = [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
			[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
		for _s in subdiv:
			var nf: Array = []
			var cache := {}
			for f in fs:
				var m: Array = []
				for e in 3:
					var a: int = f[e]
					var b: int = f[(e + 1) % 3]
					var key := Vector2i(mini(a, b), maxi(a, b))
					if not cache.has(key):
						vs.append(((vs[a] as Vector3) + (vs[b] as Vector3)).normalized())
						cache[key] = vs.size() - 1
					m.append(cache[key])
				nf.append([f[0], m[0], m[2]])
				nf.append([f[1], m[1], m[0]])
				nf.append([f[2], m[2], m[1]])
				nf.append([m[0], m[1], m[2]])
			fs = nf
		var disp: Array = []
		for v in vs:
			var vv: Vector3 = v
			disp.append(vv * (1.0 + rng.randf_range(-rough, rough)))
		for f in fs:
			var pa: Vector3 = (disp[f[0]] as Vector3) * radius
			var pb: Vector3 = (disp[f[1]] as Vector3) * radius
			var pc: Vector3 = (disp[f[2]] as Vector3) * radius
			var n := (pb - pa).cross(pc - pa).normalized()
			var cen := (pa + pb + pc) / 3.0
			var h01 := (cen.y / maxf(radius.y, 0.001) + 1.0) * 0.5
			var base := color
			if color2.a > 0.0:
				base = color.lerp(color2, clampf(h01, 0.0, 1.0))
			var cc := _col(base, h01, wind * h01)
			var ia := _v(pa, n, cc)
			var ib := _v(pb, n, cc)
			var ic := _v(pc, n, cc)
			tri(ia, ib, ic)
		pop()

	## Double-sided leaf/frond card from 4 corners (counter-clockwise when viewed from the front).
	func card(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, color: Color, wind: float = 0.0, color_tip: Color = Color(0, 0, 0, 0)) -> void:
		var n := (p1 - p0).cross(p3 - p0).normalized()
		var tip := color if color_tip.a <= 0.0 else color_tip
		for side in 2:
			var nn := n if side == 0 else -n
			var a := _v(p0, nn, _col(color, 0.0, 0.0))
			var b := _v(p1, nn, _col(color, 0.0, 0.0))
			var c := _v(p2, nn, _col(tip, 1.0, wind))
			var d := _v(p3, nn, _col(tip, 1.0, wind))
			if side == 0:
				quad_idx(a, b, c, d)
			else:
				quad_idx(a, d, c, b)

	## Curved tube following points with per-point radii (trunks, branches, tentacles).
	func tube(points: Array, radii: Array, color: Color, sides: int = 6, wind_top: float = 0.0, color_top: Color = Color(0, 0, 0, 0)) -> void:
		var rings: Array = []
		var n_pts := points.size()
		for i in n_pts:
			var p: Vector3 = points[i]
			var tdir: Vector3
			if i == 0:
				tdir = (points[1] as Vector3) - p
			elif i == n_pts - 1:
				tdir = p - (points[i - 1] as Vector3)
			else:
				tdir = (points[i + 1] as Vector3) - (points[i - 1] as Vector3)
			tdir = tdir.normalized()
			var side := tdir.cross(Vector3.RIGHT if absf(tdir.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD).normalized()
			var up := tdir.cross(side).normalized()
			var f := float(i) / float(maxi(n_pts - 1, 1))
			var c := color
			if color_top.a > 0.0:
				c = color.lerp(color_top, f)
			var ring: Array = []
			for s in sides + 1:
				var a := TAU * s / sides
				var dir := side * cos(a) + up * sin(a)
				ring.append(_v(p + dir * float(radii[i]), dir, _col(c, f, wind_top * f)))
			rings.append(ring)
		for i in n_pts - 1:
			for s in sides:
				quad_idx(rings[i][s], rings[i + 1][s], rings[i + 1][s + 1], rings[i][s + 1])
		# end cap
		var last: Vector3 = points[n_pts - 1]
		var cap := _v(last, Vector3.UP, _col(color_top if color_top.a > 0.0 else color, 1.0, wind_top))
		for s in sides:
			tri(cap, rings[n_pts - 1][s + 1], rings[n_pts - 1][s])

	## Surface of revolution from (radius, y) profile points.
	func lathe(profile: Array, color: Color, sides: int = 10, pos: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO) -> void:
		push(pos, rot_deg)
		var rings: Array = []
		var ymax := 0.001
		for p in profile:
			ymax = maxf(ymax, (p as Vector2).y)
		for i in profile.size():
			var pr: Vector2 = profile[i]
			var nxt: Vector2 = profile[mini(i + 1, profile.size() - 1)]
			var prv: Vector2 = profile[maxi(i - 1, 0)]
			var tan2 := nxt - prv
			var n2 := Vector2(tan2.y, -tan2.x).normalized()
			var ring: Array = []
			for s in sides + 1:
				var a := TAU * s / sides
				var n := Vector3(cos(a) * n2.x, n2.y, sin(a) * n2.x).normalized()
				ring.append(_v(Vector3(cos(a) * pr.x, pr.y, sin(a) * pr.x), n, _col(color, pr.y / ymax, 0.0)))
			rings.append(ring)
		for i in profile.size() - 1:
			for s in sides:
				quad_idx(rings[i][s], rings[i + 1][s], rings[i + 1][s + 1], rings[i][s + 1])
		pop()

	# ----------------------------------------------------------------- output
	func vertex_count() -> int:
		return verts.size()

	func commit(material: Material = null) -> ArrayMesh:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_NORMAL] = norms
		arr[Mesh.ARRAY_COLOR] = cols
		arr[Mesh.ARRAY_INDEX] = idx
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		if material != null:
			m.surface_set_material(0, material)
		return m

	func commit_instance(material: Material = null) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		mi.mesh = commit(material if material != null else MK_style())
		return mi

	func MK_style() -> Material:
		return load("res://scripts/gfx/mesh_kit.gd").style_material(sway)
