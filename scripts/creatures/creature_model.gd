extends RefCounted
## Procedural, replaceable creature models built from low-poly primitives.
## Each species has a distinct silhouette. To swap in real meshes later, replace build()
## for that species with a PackedScene instance that exposes the same "Rig" child.

static var _mats: Dictionary = {}


static func mat(c: Color, emit: float = 0.0) -> StandardMaterial3D:
	var key := "%s_%.1f" % [c.to_html(), emit]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	_mats[key] = m
	return m


## kind: sphere | box | cyl | cone
static func part(parent: Node3D, kind: String, size: Vector3, color: Color, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, emit: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	match kind:
		"sphere":
			var m := SphereMesh.new()
			m.radius = 0.5
			m.height = 1.0
			m.radial_segments = 10
			m.rings = 5
			mi.mesh = m
		"box":
			var b := BoxMesh.new()
			b.size = Vector3.ONE
			mi.mesh = b
		"cyl":
			var c := CylinderMesh.new()
			c.top_radius = 0.5
			c.bottom_radius = 0.5
			c.height = 1.0
			c.radial_segments = 8
			c.rings = 1
			mi.mesh = c
		"cone":
			var k := CylinderMesh.new()
			k.top_radius = 0.0
			k.bottom_radius = 0.5
			k.height = 1.0
			k.radial_segments = 8
			k.rings = 1
			mi.mesh = k
	mi.scale = size
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = mat(color, emit)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func pivot(parent: Node3D, pos: Vector3, tag: String, model: Node3D, meta: Dictionary = {}) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	for k in meta:
		n.set_meta(k, meta[k])
	parent.add_child(n)
	model.get_meta("tags")[tag].append(n)
	return n


static func leg(rig: Node3D, model: Node3D, x: float, z: float, hip_y: float, length: float, thick: float, color: Color, phase: float) -> void:
	var p := pivot(rig, Vector3(x, hip_y, z), "leg", model, {"phase": phase})
	part(p, "cyl", Vector3(thick, length, thick), color, Vector3(0, -length * 0.5, 0))


static func build(species: String) -> Node3D:
	var def: Dictionary = Data.creatures.get(species, {})
	var col: Color = def.get("color", Color(0.7, 0.7, 0.7))
	var acc: Color = def.get("accent", Color.WHITE)
	var dark := Color(0.1, 0.1, 0.12)
	var model := Node3D.new()
	model.name = "Model"
	model.set_meta("tags", {"leg": [], "wing": [], "ear": [], "tail": [], "jaw": []})
	model.set_meta("hover", float(def.get("hover", 0.0)))
	var rig := Node3D.new()
	rig.name = "Rig"
	model.add_child(rig)
	match species:
		"mossbun":
			part(rig, "sphere", Vector3(0.75, 0.65, 0.85), col, Vector3(0, 0.4, 0))
			part(rig, "sphere", Vector3(0.48, 0.42, 0.46), col.lightened(0.08), Vector3(0, 0.66, -0.4))
			for s in [-1, 1]:
				var e := pivot(rig, Vector3(0.13 * s, 0.9, -0.4), "ear", model, {"side": s})
				part(e, "cyl", Vector3(0.14, 0.6, 0.09), col.darkened(0.1), Vector3(0, 0.28, 0))
				part(rig, "sphere", Vector3(0.07, 0.07, 0.07), dark, Vector3(0.14 * s, 0.7, -0.62))
			part(rig, "sphere", Vector3(0.22, 0.22, 0.22), acc, Vector3(0, 0.38, 0.45))
			for s in [-1, 1]:
				leg(rig, model, 0.2 * s, -0.2, 0.15, 0.15, 0.14, col.darkened(0.15), 0.0 if s < 0 else PI)
		"bramblehog":
			part(rig, "sphere", Vector3(0.95, 0.7, 1.35), col, Vector3(0, 0.62, 0))
			part(rig, "sphere", Vector3(0.55, 0.5, 0.6), col.lightened(0.1), Vector3(0, 0.5, -0.85))
			part(rig, "cone", Vector3(0.18, 0.3, 0.18), dark, Vector3(0, 0.5, -1.18), Vector3(-90, 0, 0))
			for i in 7:
				var z := -0.5 + i * 0.18
				part(rig, "cone", Vector3(0.2, 0.5, 0.2), acc, Vector3(-0.22 if i % 2 == 0 else 0.22, 1.0, z), Vector3(0, 0, -20 if i % 2 == 0 else 20))
				part(rig, "cone", Vector3(0.2, 0.55, 0.2), acc.darkened(0.15), Vector3(0, 1.08, z + 0.09))
			for s in [-1, 1]:
				part(rig, "sphere", Vector3(0.08, 0.08, 0.08), dark, Vector3(0.14 * s, 0.62, -1.06))
				leg(rig, model, 0.3 * s, -0.4, 0.35, 0.35, 0.18, col.darkened(0.2), 0.0 if s < 0 else PI)
				leg(rig, model, 0.3 * s, 0.4, 0.35, 0.35, 0.18, col.darkened(0.2), PI if s < 0 else 0.0)
		"glimmerwing":
			part(rig, "sphere", Vector3(0.42, 0.42, 0.75), col, Vector3(0, 0.55, 0))
			part(rig, "sphere", Vector3(0.3, 0.3, 0.32), col.lightened(0.12), Vector3(0, 0.78, -0.42))
			part(rig, "cone", Vector3(0.12, 0.3, 0.12), acc, Vector3(0, 0.76, -0.68), Vector3(-90, 0, 0))
			for s in [-1, 1]:
				var w := pivot(rig, Vector3(0.18 * s, 0.62, -0.05), "wing", model, {"side": s})
				part(w, "box", Vector3(1.0, 0.04, 0.5), col.lightened(0.2), Vector3(0.5 * s, 0, 0.05))
				part(w, "box", Vector3(0.55, 0.045, 0.3), acc, Vector3(0.9 * s, 0.01, 0.16), Vector3(0, -10 * s, 0), 0.6)
				part(rig, "sphere", Vector3(0.06, 0.06, 0.06), dark, Vector3(0.1 * s, 0.84, -0.55))
			for i in 3:
				part(rig, "box", Vector3(0.1, 0.03, 0.55), acc, Vector3((i - 1) * 0.1, 0.5, 0.65), Vector3(0, (i - 1) * 12, 0))
		"lumifox":
			part(rig, "sphere", Vector3(0.38, 0.4, 1.0), col, Vector3(0, 0.62, 0))
			part(rig, "sphere", Vector3(0.34, 0.32, 0.4), col.lightened(0.1), Vector3(0, 0.82, -0.62))
			part(rig, "cone", Vector3(0.14, 0.26, 0.14), dark, Vector3(0, 0.78, -0.88), Vector3(-90, 0, 0))
			for s in [-1, 1]:
				part(rig, "cone", Vector3(0.14, 0.3, 0.1), acc.darkened(0.2), Vector3(0.12 * s, 1.08, -0.58))
				part(rig, "sphere", Vector3(0.06, 0.06, 0.06), dark, Vector3(0.1 * s, 0.86, -0.8))
				leg(rig, model, 0.14 * s, -0.35, 0.5, 0.5, 0.1, col.darkened(0.25), 0.0 if s < 0 else PI)
				leg(rig, model, 0.14 * s, 0.35, 0.5, 0.5, 0.1, col.darkened(0.25), PI if s < 0 else 0.0)
			var t := pivot(rig, Vector3(0, 0.7, 0.55), "tail", model)
			part(t, "sphere", Vector3(0.36, 0.34, 0.9), col.lightened(0.15), Vector3(0, 0.05, 0.45))
			part(t, "sphere", Vector3(0.3, 0.3, 0.3), acc, Vector3(0, 0.08, 0.95), Vector3.ZERO, 2.2)
		"pondling":
			part(rig, "sphere", Vector3(0.95, 0.42, 1.05), col, Vector3(0, 0.32, 0))
			part(rig, "sphere", Vector3(0.7, 0.32, 0.5), col.lightened(0.1), Vector3(0, 0.38, -0.66))
			part(rig, "sphere", Vector3(0.7, 0.18, 0.7), acc.lightened(0.2), Vector3(0, 0.15, 0.0))
			for s in [-1, 1]:
				part(rig, "sphere", Vector3(0.24, 0.24, 0.24), acc, Vector3(0.24 * s, 0.62, -0.62))
				part(rig, "sphere", Vector3(0.1, 0.1, 0.1), dark, Vector3(0.24 * s, 0.66, -0.74))
				var l := pivot(rig, Vector3(0.45 * s, 0.2, -0.3), "leg", model, {"phase": 0.0 if s < 0 else PI})
				part(l, "box", Vector3(0.3, 0.08, 0.3), col.darkened(0.2), Vector3(0.1 * s, -0.12, -0.05))
				var l2 := pivot(rig, Vector3(0.45 * s, 0.2, 0.35), "leg", model, {"phase": PI if s < 0 else 0.0})
				part(l2, "box", Vector3(0.3, 0.08, 0.3), col.darkened(0.2), Vector3(0.1 * s, -0.12, 0.05))
		"snailbell":
			part(rig, "sphere", Vector3(0.48, 0.24, 1.15), col, Vector3(0, 0.14, 0))
			part(rig, "sphere", Vector3(0.3, 0.3, 0.3), col.lightened(0.1), Vector3(0, 0.3, -0.58))
			for s in [-1, 1]:
				part(rig, "cyl", Vector3(0.05, 0.3, 0.05), col, Vector3(0.1 * s, 0.5, -0.62))
				part(rig, "sphere", Vector3(0.1, 0.1, 0.1), dark, Vector3(0.1 * s, 0.66, -0.62))
			part(rig, "sphere", Vector3(0.75, 0.7, 0.75), acc, Vector3(0, 0.62, 0.12))
			var bell := pivot(rig, Vector3(0, 1.0, 0.12), "tail", model)
			part(bell, "cone", Vector3(0.5, 0.45, 0.5), acc.lightened(0.3), Vector3(0, 0.1, 0), Vector3(180, 0, 0), 0.5)
			part(bell, "sphere", Vector3(0.1, 0.1, 0.1), Color(1, 0.9, 0.5), Vector3(0, -0.12, 0), Vector3.ZERO, 1.0)
		"thistlefinch":
			part(rig, "sphere", Vector3(0.5, 0.48, 0.55), col, Vector3(0, 0.6, 0))
			part(rig, "sphere", Vector3(0.3, 0.3, 0.3), col.lightened(0.1), Vector3(0, 0.82, -0.28))
			part(rig, "cone", Vector3(0.1, 0.18, 0.1), dark, Vector3(0, 0.8, -0.5), Vector3(-90, 0, 0))
			for i in 3:
				part(rig, "cone", Vector3(0.07, 0.28, 0.07), acc, Vector3((i - 1) * 0.07, 1.06, -0.24), Vector3(0, 0, (i - 1) * 25))
			for s in [-1, 1]:
				var w := pivot(rig, Vector3(0.22 * s, 0.65, 0), "wing", model, {"side": s})
				part(w, "box", Vector3(0.5, 0.03, 0.3), col.darkened(0.15), Vector3(0.25 * s, 0, 0))
				part(rig, "sphere", Vector3(0.05, 0.05, 0.05), dark, Vector3(0.1 * s, 0.86, -0.4))
			part(rig, "box", Vector3(0.12, 0.03, 0.35), acc, Vector3(0, 0.55, 0.42), Vector3(10, 0, 0))
		"cinderstag":
			part(rig, "sphere", Vector3(0.6, 0.62, 1.25), col, Vector3(0, 1.25, 0))
			part(rig, "cyl", Vector3(0.22, 0.75, 0.22), col, Vector3(0, 1.7, -0.62), Vector3(-30, 0, 0))
			part(rig, "sphere", Vector3(0.32, 0.32, 0.5), col.lightened(0.08), Vector3(0, 2.05, -0.85))
			for s in [-1, 1]:
				part(rig, "cyl", Vector3(0.05, 0.7, 0.05), acc, Vector3(0.14 * s, 2.35, -0.78), Vector3(0, 0, -18 * s), 1.8)
				part(rig, "cyl", Vector3(0.04, 0.4, 0.04), acc, Vector3(0.3 * s, 2.55, -0.78), Vector3(0, 0, -50 * s), 1.8)
				part(rig, "cyl", Vector3(0.04, 0.35, 0.04), acc, Vector3(0.2 * s, 2.5, -0.9), Vector3(30, 0, -20 * s), 1.8)
				part(rig, "sphere", Vector3(0.06, 0.06, 0.06), dark, Vector3(0.14 * s, 2.1, -1.02))
				leg(rig, model, 0.2 * s, -0.45, 1.0, 1.0, 0.11, col.darkened(0.3), 0.0 if s < 0 else PI)
				leg(rig, model, 0.2 * s, 0.45, 1.0, 1.0, 0.11, col.darkened(0.3), PI if s < 0 else 0.0)
			part(rig, "sphere", Vector3(0.2, 0.2, 0.3), acc, Vector3(0, 1.4, 0.72), Vector3.ZERO, 1.0)
		"rustmaw":
			part(rig, "sphere", Vector3(1.5, 1.2, 2.2), col, Vector3(0, 1.15, 0))
			part(rig, "box", Vector3(1.05, 0.8, 1.0), col.lightened(0.05), Vector3(0, 1.35, -1.45))
			var jaw := pivot(rig, Vector3(0, 0.95, -1.7), "jaw", model)
			part(jaw, "box", Vector3(0.9, 0.22, 0.9), col.darkened(0.25), Vector3(0, -0.05, 0.4))
			for i in 5:
				part(rig, "box", Vector3(0.9 - i * 0.08, 0.18, 0.4), acc.darkened(0.3), Vector3(0, 1.95 - i * 0.03, -0.7 + i * 0.4), Vector3((i - 2) * 6, 0, 0))
			for s in [-1, 1]:
				part(rig, "cone", Vector3(0.18, 0.55, 0.18), Color(0.85, 0.8, 0.7), Vector3(0.42 * s, 1.9, -1.4), Vector3(0, 0, -20 * s))
				part(rig, "sphere", Vector3(0.14, 0.14, 0.14), acc, Vector3(0.28 * s, 1.5, -1.95), Vector3.ZERO, 2.5)
				leg(rig, model, 0.6 * s, -0.7, 0.9, 0.9, 0.34, col.darkened(0.3), 0.0 if s < 0 else PI)
				leg(rig, model, 0.6 * s, 0.7, 0.9, 0.9, 0.34, col.darkened(0.3), PI if s < 0 else 0.0)
			part(rig, "cone", Vector3(0.3, 0.7, 0.3), acc.darkened(0.2), Vector3(0, 1.3, 1.3), Vector3(90, 0, 0), 0.6)
		_:
			part(rig, "sphere", Vector3(0.8, 0.8, 0.8), col, Vector3(0, 0.4, 0))
	var sc: float = float(def.get("scale", 1.0))
	model.scale = Vector3(sc, sc, sc)
	return model


## Procedural animation. state: "" | "happy" | "puff" | "attack"
static func animate(model: Node3D, t: float, speed: float, state: String = "") -> void:
	if model == null or not model.has_meta("tags"):
		return
	var tags: Dictionary = model.get_meta("tags")
	var rig: Node3D = model.get_node("Rig")
	var moving := speed > 0.3
	var hover: float = model.get_meta("hover", 0.0)
	var y := hover
	if hover > 0.0:
		y += sin(t * 3.0) * 0.1
	elif moving:
		y += absf(sin(t * 8.0)) * 0.06
	else:
		y += sin(t * 2.0) * 0.015
	var sc := 1.0
	if state == "happy":
		y += absf(sin(t * 10.0)) * 0.3
	elif state == "puff":
		sc = 1.0 + 0.12 * sin(t * 12.0)
	rig.position.y = y
	rig.scale = Vector3(sc, sc, sc)
	for l in tags["leg"]:
		var ph: float = l.get_meta("phase", 0.0)
		var target := sin(t * 9.0 + ph) * 0.7 if moving else 0.0
		l.rotation.x = lerpf(l.rotation.x, target, 0.3)
	var flap_speed := 14.0 if (moving or hover > 0.0) else 3.0
	for w in tags["wing"]:
		var side: float = w.get_meta("side", 1.0)
		w.rotation.z = side * sin(t * flap_speed) * (0.7 if flap_speed > 5.0 else 0.15)
	for e in tags["ear"]:
		e.rotation.x = sin(t * 2.5 + float(e.get_meta("side", 1))) * 0.18
	for tl in tags["tail"]:
		tl.rotation.y = sin(t * 4.0) * 0.35
	for j in tags["jaw"]:
		j.rotation.x = (0.5 if state == "attack" else 0.05 + 0.04 * sin(t * 3.0))
