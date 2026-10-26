extends RefCounted
## Procedural creature and boss part meshes. Each builder returns {parts: {name: [mesh, pivot_pos]}, ...}.

const MK = preload("res://scripts/gfx/mesh_kit.gd")


static func _mat(emissive: float = 0.0) -> ShaderMaterial:
	return MK.style_material(0.0, 0.35, emissive).duplicate() as ShaderMaterial


## Returns a Node3D with named child pivots (each containing a MeshInstance3D) for animation.
static func build(kind: String) -> Node3D:
	match kind:
		"stalker": return _stalker()
		"brute": return _brute()
		"wraith": return _wraith()
		"sentinel": return _sentinel()
		"grove_guardian": return _grove_guardian()
		"furnace_colossus": return _colossus()
		"core_architect": return _architect()
		"crab": return _crab()
		"mossdeer": return _deer()
		"ridge_goat": return _goat()
		"ember_newt": return _newt()
	return Node3D.new()


static func _part(root: Node3D, name: String, pos: Vector3, b: MK.Builder, emissive: float = 0.0) -> Node3D:
	var piv := Node3D.new()
	piv.name = name
	piv.position = pos
	var mi := b.commit_instance(_mat(emissive))
	piv.add_child(mi)
	root.add_child(piv)
	return piv


static func _b(seed: int) -> MK.Builder:
	var b := MK.Builder.new(seed)
	b.jitter = 0.05
	return b


# ------------------------------------------------------------------ Forest Stalker (quadruped)
static func _stalker() -> Node3D:
	var r := Node3D.new()
	var fur := Color(0.30, 0.24, 0.17)
	var moss := Color(0.25, 0.42, 0.20)
	var b := _b(11)
	b.blob(Vector3(0.42, 0.36, 0.85), fur, Vector3(0, 0, 0), 0.12, 1)
	b.blob(Vector3(0.36, 0.14, 0.6), moss, Vector3(0, 0.26, 0.05), 0.2, 1)
	for i in 4:
		b.cone(0.1, 0.45, Color(0.45, 0.33, 0.2), Vector3(0, 0.3, -0.45 + i * 0.3), Vector3(-15, 0, 0), 5)
	b.tube([Vector3(0, 0.1, 0.7), Vector3(0, 0.25, 1.1), Vector3(0, 0.1, 1.5)], [0.12, 0.08, 0.02], Color(0.35, 0.27, 0.18), 5)
	_part(r, "body", Vector3(0, 0.78, 0), b)
	var h := _b(12)
	h.blob(Vector3(0.26, 0.24, 0.34), fur.lightened(0.05), Vector3(0, 0, 0), 0.1, 1)
	h.cone(0.07, 0.35, Color(0.5, 0.38, 0.24), Vector3(-0.15, 0.2, 0.0), Vector3(0, 0, 25), 5)
	h.cone(0.07, 0.35, Color(0.5, 0.38, 0.24), Vector3(0.15, 0.2, 0.0), Vector3(0, 0, -25), 5)
	h.cone(0.05, 0.25, Color(0.5, 0.38, 0.24), Vector3(-0.2, 0.3, -0.1), Vector3(-20, 0, 40), 5)
	h.cone(0.05, 0.25, Color(0.5, 0.38, 0.24), Vector3(0.2, 0.3, -0.1), Vector3(-20, 0, -40), 5)
	h.sphere(Vector3(0.05, 0.05, 0.03), Color(1.0, 0.75, 0.2), Vector3(-0.1, 0.06, -0.3), Vector3.ZERO, 3, 6)
	h.sphere(Vector3(0.05, 0.05, 0.03), Color(1.0, 0.75, 0.2), Vector3(0.1, 0.06, -0.3), Vector3.ZERO, 3, 6)
	h.box(Vector3(0.14, 0.08, 0.22), Color(0.2, 0.15, 0.1), Vector3(0, -0.1, -0.35))
	_part(r, "head", Vector3(0, 0.95, -0.85), h, 0.25)
	for i in 4:
		var lb := _b(20 + i)
		lb.cyl(0.09, 0.06, 0.55, fur.darkened(0.1), Vector3(0, -0.5, 0), Vector3.ZERO, 6)
		lb.cyl(0.07, 0.07, 0.1, Color(0.15, 0.1, 0.07), Vector3(0, -0.5, 0), Vector3.ZERO, 6)
		_part(r, "leg%d" % i, Vector3(-0.26 if i % 2 == 0 else 0.26, 0.72, -0.5 if i < 2 else 0.45), lb)
	return r


# ------------------------------------------------------------------ Rockback Brute (hulking biped)
static func _brute() -> Node3D:
	var r := Node3D.new()
	var skin := Color(0.45, 0.40, 0.36)
	var rock := Color(0.40, 0.40, 0.42)
	var b := _b(31)
	b.blob(Vector3(0.9, 0.85, 0.65), skin, Vector3(0, 0, 0), 0.12, 1)
	for i in 6:
		var a := i * 0.9
		b.blob(Vector3(0.38, 0.3, 0.3), rock.lightened(0.05 * (i % 3)), Vector3(sin(a) * 0.45, 0.55 - i * 0.12 + 0.2, 0.55), 0.3, 1, Vector3(20, a * 20, 15))
	b.blob(Vector3(0.55, 0.4, 0.5), rock, Vector3(0, 0.6, 0.45), 0.25, 1)
	for i in 5:
		b.cone(0.16, 0.6, rock.darkened(0.15), Vector3(-0.5 + i * 0.25, 0.8, 0.45), Vector3(-30, 0, (i - 2) * 8), 5)
	_part(r, "body", Vector3(0, 1.55, 0), b)
	var h := _b(32)
	h.blob(Vector3(0.28, 0.26, 0.28), skin.lightened(0.1), Vector3.ZERO, 0.1, 1)
	h.box(Vector3(0.4, 0.08, 0.1), Color(0.15, 0.1, 0.1), Vector3(0, 0.0, -0.22))
	h.sphere(Vector3(0.04, 0.04, 0.03), Color(1, 0.5, 0.15), Vector3(-0.1, 0.05, -0.26), Vector3.ZERO, 3, 6)
	h.sphere(Vector3(0.04, 0.04, 0.03), Color(1, 0.5, 0.15), Vector3(0.1, 0.05, -0.26), Vector3.ZERO, 3, 6)
	_part(r, "head", Vector3(0, 2.25, -0.35), h, 0.3)
	for s in [-1, 1]:
		var ab := _b(40 + s)
		ab.cyl(0.22, 0.2, 0.9, skin, Vector3(0, -0.9, 0), Vector3.ZERO, 7)
		ab.blob(Vector3(0.32, 0.32, 0.32), skin.darkened(0.1), Vector3(0, -1.0, 0), 0.15, 1)
		ab.blob(Vector3(0.36, 0.3, 0.36), rock, Vector3(0, -1.0, 0), 0.25, 1)
		_part(r, "arm%d" % (0 if s < 0 else 1), Vector3(s * 0.95, 1.95, 0), ab)
		var lb := _b(50 + s)
		lb.cyl(0.28, 0.22, 0.95, skin.darkened(0.1), Vector3(0, -0.95, 0), Vector3.ZERO, 7)
		lb.box(Vector3(0.5, 0.15, 0.7), rock.darkened(0.2), Vector3(0, -0.95, -0.12))
		_part(r, "leg%d" % (0 if s < 0 else 1), Vector3(s * 0.4, 1.0, 0), lb)
	return r


# ------------------------------------------------------------------ Crystal Wraith (floating caster)
static func _wraith() -> Node3D:
	var r := Node3D.new()
	var core := Color(0.45, 0.9, 1.0)
	var cloak := Color(0.22, 0.18, 0.36)
	var b := _b(61)
	b.cone(0.5, 1.5, cloak, Vector3(0, -1.0, 0), Vector3(180, 0, 0), 9)
	b.cone(0.42, 1.0, cloak.lightened(0.1), Vector3(0.0, -0.4, 0.05), Vector3(180, 0, 0), 7)
	for i in 6:
		var a := i * TAU / 6.0
		b.cone(0.09, 0.7 + 0.2 * (i % 2), cloak.darkened(0.1), Vector3(cos(a) * 0.42, -1.05, sin(a) * 0.42), Vector3(165, 0, 0), 5)
	_part(r, "body", Vector3(0, 1.7, 0), b)
	var c := _b(62)
	c.sphere(Vector3(0.22, 0.3, 0.22), core, Vector3.ZERO, Vector3.ZERO, 4, 8)
	c.sphere(Vector3(0.12, 0.17, 0.12), Color(1, 1, 1), Vector3.ZERO, Vector3.ZERO, 3, 6)
	_part(r, "core", Vector3(0, 2.15, -0.05), c, 0.9)
	var sh := _b(63)
	for i in 5:
		var a2 := i * TAU / 5.0
		sh.cone(0.09, 0.5, core.lightened(0.1), Vector3(cos(a2) * 0.75, 0, sin(a2) * 0.75), Vector3(0, 0, 0), 4)
		sh.cone(0.09, 0.3, core, Vector3(cos(a2) * 0.75, 0, sin(a2) * 0.75), Vector3(180, 0, 0), 4)
	_part(r, "ring", Vector3(0, 1.9, 0), sh, 0.8)
	return r


# ------------------------------------------------------------------ Ruin Sentinel (machine)
static func _sentinel() -> Node3D:
	var r := Node3D.new()
	var metal := Color(0.50, 0.53, 0.58)
	var rust := Color(0.58, 0.38, 0.24)
	var cop := Color(0.78, 0.48, 0.28)
	var b := _b(71)
	b.box(Vector3(1.1, 1.1, 0.8), metal, Vector3(0, 0, 0))
	b.box(Vector3(1.2, 0.2, 0.9), rust, Vector3(0, 0.5, 0))
	b.box(Vector3(0.7, 0.5, 0.1), cop, Vector3(0, 0.0, -0.42))
	b.cyl(0.12, 0.12, 0.5, metal.darkened(0.2), Vector3(-0.4, 0.55, 0.3), Vector3.ZERO, 6)
	b.cyl(0.12, 0.12, 0.5, metal.darkened(0.2), Vector3(0.4, 0.55, 0.3), Vector3.ZERO, 6)
	b.box(Vector3(0.9, 0.9, 0.12), metal.darkened(0.1), Vector3(0, 0, 0.46))
	_part(r, "body", Vector3(0, 1.75, 0), b)
	var h := _b(72)
	h.cyl(0.32, 0.28, 0.3, metal, Vector3(0, -0.15, 0), Vector3.ZERO, 8)
	h.sphere(Vector3(0.3, 0.2, 0.3), metal.lightened(0.1), Vector3(0, 0.05, 0), Vector3.ZERO, 4, 8)
	h.sphere(Vector3(0.12, 0.12, 0.06), Color(1.0, 0.25, 0.2), Vector3(0, 0.05, -0.27), Vector3.ZERO, 4, 8)
	_part(r, "head", Vector3(0, 2.5, 0), h, 0.5)
	for s in [-1, 1]:
		var ab := _b(80 + s)
		ab.cyl(0.14, 0.12, 0.9, metal.darkened(0.1), Vector3(0, -0.85, 0), Vector3.ZERO, 6)
		ab.box(Vector3(0.4, 0.4, 0.5), rust, Vector3(0, -1.0, 0))
		ab.box(Vector3(0.12, 0.7, 0.3), cop, Vector3(0, -1.45, -0.05))
		_part(r, "arm%d" % (0 if s < 0 else 1), Vector3(s * 0.78, 2.15, 0), ab)
		var lb := _b(90 + s)
		lb.cyl(0.14, 0.1, 1.0, metal.darkened(0.2), Vector3(0, -1.0, 0), Vector3.ZERO, 6)
		lb.box(Vector3(0.45, 0.14, 0.65), rust.darkened(0.1), Vector3(0, -1.0, -0.1))
		_part(r, "leg%d" % (0 if s < 0 else 1), Vector3(s * 0.35, 1.2, 0), lb)
	return r


# ------------------------------------------------------------------ Bosses
static func _grove_guardian() -> Node3D:
	var r := Node3D.new()
	var bark := Color(0.34, 0.24, 0.15)
	var moss := Color(0.25, 0.46, 0.2)
	var b := _b(101)
	b.blob(Vector3(2.0, 2.4, 1.6), bark, Vector3(0, 0, 0), 0.18, 2)
	b.blob(Vector3(1.8, 0.9, 1.5), moss, Vector3(0, 1.5, 0.1), 0.25, 1)
	for i in 8:
		var a := i * TAU / 8.0
		b.cone(0.28, 1.7, bark.lightened(0.08), Vector3(cos(a) * 1.35, 1.6, sin(a) * 1.0), Vector3(sin(a) * 25, 0, -cos(a) * 25), 5)
	b.sphere(Vector3(0.5, 0.7, 0.2), Color(1.0, 0.7, 0.2), Vector3(0, 0.3, -1.45), Vector3.ZERO, 4, 8)
	_part(r, "body", Vector3(0, 3.9, 0), b, 0.0)
	var h := _b(102)
	h.blob(Vector3(0.7, 0.75, 0.65), bark.lightened(0.1), Vector3.ZERO, 0.15, 1)
	for s in [-1, 1]:
		h.cone(0.14, 1.4, bark.darkened(0.1), Vector3(s * 0.5, 0.5, 0), Vector3(0, 0, -s * 30), 5)
		h.cone(0.1, 0.9, bark, Vector3(s * 0.85, 0.9, 0), Vector3(0, 0, -s * 55), 5)
		h.sphere(Vector3(0.12, 0.09, 0.07), Color(1.0, 0.8, 0.2), Vector3(s * 0.27, 0.1, -0.6), Vector3.ZERO, 4, 6)
	h.box(Vector3(0.5, 0.1, 0.2), Color(0.12, 0.08, 0.05), Vector3(0, -0.3, -0.55))
	_part(r, "head", Vector3(0, 5.6, -0.4), h, 0.35)
	for s in [-1, 1]:
		var ab := _b(110 + s)
		ab.cyl(0.45, 0.38, 2.3, bark, Vector3(0, -2.2, 0), Vector3.ZERO, 7)
		ab.blob(Vector3(0.7, 0.65, 0.7), bark.darkened(0.1), Vector3(0, -2.4, 0), 0.25, 1)
		for k in 3:
			ab.cone(0.12, 0.7, bark.lightened(0.1), Vector3(-0.3 + k * 0.3, -2.6, -0.35), Vector3(-80, 0, 0), 5)
		_part(r, "arm%d" % (0 if s < 0 else 1), Vector3(s * 2.1, 4.9, 0), ab)
		var lb := _b(120 + s)
		lb.cyl(0.55, 0.45, 2.0, bark.darkened(0.15), Vector3(0, -2.0, 0), Vector3.ZERO, 7)
		lb.blob(Vector3(0.7, 0.3, 0.9), moss.darkened(0.2), Vector3(0, -2.0, -0.15), 0.2, 1)
		_part(r, "leg%d" % (0 if s < 0 else 1), Vector3(s * 0.9, 2.2, 0), lb)
	return r


static func _colossus() -> Node3D:
	var r := Node3D.new()
	var dark := Color(0.20, 0.19, 0.21)
	var steel := Color(0.40, 0.40, 0.44)
	var glow := Color(1.0, 0.45, 0.12)
	var b := _b(131)
	b.box(Vector3(3.4, 3.2, 2.4), dark, Vector3.ZERO)
	b.box(Vector3(3.6, 0.5, 2.6), steel, Vector3(0, 1.45, 0))
	b.box(Vector3(2.0, 1.6, 0.25), glow, Vector3(0, 0.1, -1.25))
	for i in 5:
		b.box(Vector3(0.25, 1.5, 0.3), dark.darkened(0.3), Vector3(-0.8 + i * 0.4, 0.1, -1.4))
	for s in [-1, 1]:
		b.cyl(0.3, 0.3, 1.8, steel, Vector3(s * 1.0, 1.6, 0.7), Vector3.ZERO, 8)
		b.cyl(0.4, 0.3, 0.3, glow, Vector3(s * 1.0, 3.35, 0.7), Vector3.ZERO, 8)
	b.box(Vector3(2.0, 1.8, 0.2), steel.darkened(0.2), Vector3(0, 0, 1.3))
	_part(r, "body", Vector3(0, 5.2, 0), b, 0.15)
	var h := _b(132)
	h.box(Vector3(1.3, 1.0, 1.2), steel, Vector3.ZERO)
	h.box(Vector3(1.0, 0.25, 0.1), glow, Vector3(0, 0.05, -0.62))
	h.cone(0.3, 0.6, dark, Vector3(0, 0.5, 0), Vector3.ZERO, 6)
	_part(r, "head", Vector3(0, 7.4, -0.2), h, 0.6)
	for s in [-1, 1]:
		var ab := _b(140 + s)
		ab.cyl(0.55, 0.5, 2.6, dark, Vector3(0, -2.6, 0), Vector3.ZERO, 8)
		ab.box(Vector3(1.4, 1.6, 1.4), steel, Vector3(0, -3.2, 0))
		ab.box(Vector3(1.0, 0.3, 1.0), glow, Vector3(0, -4.1, 0))
		_part(r, "arm%d" % (0 if s < 0 else 1), Vector3(s * 2.5, 6.4, 0), ab, 0.1)
		var lb := _b(150 + s)
		lb.box(Vector3(1.1, 2.6, 1.1), dark.lightened(0.05), Vector3(0, -1.3, 0))
		lb.box(Vector3(1.6, 0.4, 2.0), steel, Vector3(0, -2.6, -0.2))
		_part(r, "leg%d" % (0 if s < 0 else 1), Vector3(s * 1.1, 2.9, 0), lb)
	return r


static func _architect() -> Node3D:
	var r := Node3D.new()
	var shell := Color(0.30, 0.34, 0.42)
	var glow := Color(0.45, 0.9, 1.0)
	var b := _b(161)
	b.sphere(Vector3(1.5, 1.9, 1.5), shell, Vector3.ZERO, Vector3.ZERO, 6, 12)
	b.sphere(Vector3(0.8, 1.0, 0.8), glow, Vector3.ZERO, Vector3.ZERO, 5, 10)
	b.cyl(0.8, 0.8, 0.12, glow.darkened(0.2), Vector3(0, -0.2, 0), Vector3.ZERO, 14)
	_part(r, "body", Vector3(0, 4.0, 0), b, 0.6)
	var ring := _b(162)
	for i in 8:
		var a := i * TAU / 8.0
		ring.box(Vector3(0.5, 2.0, 0.4), shell.lightened(0.08), Vector3(cos(a) * 2.7, 0, sin(a) * 2.7), Vector3(0, -rad_to_deg(a), 8))
		ring.cone(0.18, 0.7, glow, Vector3(cos(a) * 2.7, 1.0, sin(a) * 2.7), Vector3.ZERO, 4)
	_part(r, "ring", Vector3(0, 4.0, 0), ring, 0.5)
	var ring2 := _b(163)
	for i in 6:
		var a2 := i * TAU / 6.0
		ring2.box(Vector3(0.35, 1.4, 0.35), glow.darkened(0.25), Vector3(cos(a2) * 1.9, 0, sin(a2) * 1.9))
	_part(r, "ring2", Vector3(0, 4.0, 0), ring2, 0.8)
	return r


# ------------------------------------------------------------------ Wildlife
static func _crab() -> Node3D:
	var r := Node3D.new()
	var b := _b(201)
	b.blob(Vector3(0.38, 0.17, 0.3), Color(0.85, 0.42, 0.28), Vector3.ZERO, 0.1, 1)
	b.sphere(Vector3(0.05, 0.05, 0.05), Color(0.1, 0.1, 0.1), Vector3(-0.12, 0.2, -0.22), Vector3.ZERO, 3, 5)
	b.sphere(Vector3(0.05, 0.05, 0.05), Color(0.1, 0.1, 0.1), Vector3(0.12, 0.2, -0.22), Vector3.ZERO, 3, 5)
	for s in [-1, 1]:
		b.blob(Vector3(0.14, 0.1, 0.18), Color(0.92, 0.5, 0.32), Vector3(s * 0.45, 0.05, -0.28), 0.1, 1)
		for k in 3:
			b.cyl(0.025, 0.02, 0.3, Color(0.75, 0.35, 0.24), Vector3(s * 0.3, -0.05, -0.1 + k * 0.14), Vector3(0, 0, s * 70), 4)
	_part(r, "body", Vector3(0, 0.2, 0), b)
	return r


static func _deer() -> Node3D:
	var r := Node3D.new()
	var fur := Color(0.62, 0.48, 0.32)
	var b := _b(211)
	b.blob(Vector3(0.38, 0.4, 0.8), fur, Vector3.ZERO, 0.08, 1)
	b.blob(Vector3(0.3, 0.2, 0.5), Color(0.9, 0.85, 0.75), Vector3(0, -0.2, 0.0), 0.08, 1)
	b.blob(Vector3(0.2, 0.2, 0.2), Color(0.9, 0.85, 0.75), Vector3(0, 0.1, 0.78), 0.05, 1)
	_part(r, "body", Vector3(0, 1.05, 0), b)
	var h := _b(212)
	h.blob(Vector3(0.18, 0.2, 0.3), fur.lightened(0.05), Vector3(0, 0.0, -0.2), 0.05, 1)
	h.cyl(0.1, 0.12, 0.6, fur, Vector3(0, -0.4, 0.1), Vector3(-25, 0, 0), 6)
	for s in [-1, 1]:
		h.cone(0.04, 0.5, Color(0.55, 0.45, 0.3), Vector3(s * 0.12, 0.2, -0.1), Vector3(0, 0, -s * 25), 4)
		h.cone(0.03, 0.3, Color(0.55, 0.45, 0.3), Vector3(s * 0.2, 0.45, -0.1), Vector3(0, 0, -s * 45), 4)
		h.sphere(Vector3(0.03, 0.03, 0.03), Color(0.05, 0.05, 0.05), Vector3(s * 0.12, 0.05, -0.4), Vector3.ZERO, 3, 5)
	_part(r, "head", Vector3(0, 1.45, -0.85), h)
	for i in 4:
		var lb := _b(215 + i)
		lb.cyl(0.07, 0.04, 1.0, fur.darkened(0.15), Vector3(0, -1.0, 0), Vector3.ZERO, 5)
		_part(r, "leg%d" % i, Vector3(-0.2 if i % 2 == 0 else 0.2, 1.0, -0.5 if i < 2 else 0.5), lb)
	return r


static func _goat() -> Node3D:
	var r := Node3D.new()
	var fur := Color(0.78, 0.76, 0.70)
	var b := _b(221)
	b.blob(Vector3(0.36, 0.34, 0.65), fur, Vector3.ZERO, 0.1, 1)
	b.blob(Vector3(0.3, 0.2, 0.4), Color(0.55, 0.5, 0.45), Vector3(0, 0.2, 0.1), 0.1, 1)
	_part(r, "body", Vector3(0, 0.95, 0), b)
	var h := _b(222)
	h.blob(Vector3(0.16, 0.2, 0.26), fur.lightened(0.05), Vector3.ZERO, 0.05, 1)
	h.cone(0.08, 0.2, fur, Vector3(0, -0.2, -0.15), Vector3(10, 0, 0), 5)
	for s in [-1, 1]:
		h.tube([Vector3(s * 0.1, 0.15, 0.0), Vector3(s * 0.2, 0.4, 0.1), Vector3(s * 0.15, 0.55, 0.3)], [0.06, 0.05, 0.015], Color(0.45, 0.4, 0.32), 5)
	_part(r, "head", Vector3(0, 1.2, -0.7), h)
	for i in 4:
		var lb := _b(225 + i)
		lb.cyl(0.06, 0.04, 0.9, fur.darkened(0.2), Vector3(0, -0.9, 0), Vector3.ZERO, 5)
		_part(r, "leg%d" % i, Vector3(-0.17 if i % 2 == 0 else 0.17, 0.9, -0.42 if i < 2 else 0.4), lb)
	return r


static func _newt() -> Node3D:
	var r := Node3D.new()
	var b := _b(231)
	b.blob(Vector3(0.22, 0.14, 0.55), Color(0.25, 0.2, 0.2), Vector3.ZERO, 0.08, 1)
	for i in 5:
		b.sphere(Vector3(0.07, 0.04, 0.09), Color(1.0, 0.5, 0.15), Vector3(0, 0.12, -0.3 + i * 0.16), Vector3.ZERO, 3, 5)
	b.tube([Vector3(0, 0, 0.5), Vector3(0, 0.02, 0.9), Vector3(0.1, 0, 1.3)], [0.1, 0.06, 0.01], Color(0.3, 0.22, 0.2), 5)
	b.sphere(Vector3(0.1, 0.09, 0.14), Color(0.3, 0.24, 0.22), Vector3(0, 0.02, -0.6), Vector3.ZERO, 3, 6)
	_part(r, "body", Vector3(0, 0.22, 0), b, 0.2)
	return r
