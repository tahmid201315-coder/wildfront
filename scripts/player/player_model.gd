extends Node3D
## Procedural explorer: a jointed model (one merged mesh per body part) with smooth pose blending.
## The controller sets `state`, `speed01`, and phase values; this node turns them into joint rotations.

const MK = preload("res://scripts/gfx/mesh_kit.gd")

var state: String = "idle"
var speed01: float = 0.0          # 0..1 horizontal speed (walk ~0.4, run ~0.7, sprint 1)
var phase_t: float = 0.0          # seconds inside the current action (attack / gather / dodge ...)
var action_len: float = 0.5
var action_kind: String = ""      # swing1 swing2 swing3 thrust heavy shoot chop mine pluck
var crouch: bool = false
var climb_lean: float = 0.0

var hips: Node3D
var torso: Node3D
var head: Node3D
var sh_l: Node3D
var sh_r: Node3D
var el_l: Node3D
var el_r: Node3D
var hp_l: Node3D
var hp_r: Node3D
var kn_l: Node3D
var kn_r: Node3D
var hand_r: Node3D
var weapon_node: Node3D
var back_node: Node3D
var _t: float = 0.0
var _pose: Dictionary = {}
var _gait: float = 0.0
var _joints: Dictionary = {}

const SKIN := Color(0.88, 0.68, 0.52)
const HAIR := Color(0.20, 0.13, 0.10)
const JACKET := Color(0.24, 0.50, 0.58)
const JACKET_TRIM := Color(0.90, 0.62, 0.20)
const PANTS := Color(0.26, 0.28, 0.34)
const BOOT := Color(0.28, 0.20, 0.15)


func _ready() -> void:
	_build()
	rebuild_equipment()


func _mi(b: MK.Builder, parent: Node3D, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = b.commit(MK.style_material(0.0, 0.3, 0.0))
	m.position = pos
	parent.add_child(m)
	return m


func _joint(parent: Node3D, pos: Vector3, key: String) -> Node3D:
	var j := Node3D.new()
	j.position = pos
	parent.add_child(j)
	_joints[key] = j
	return j


func _build() -> void:
	var armor_col := JACKET
	var suit: Dictionary = Game.equip.get("suit", {})
	var armor: Dictionary = Game.equip.get("armor", {})
	if not suit.is_empty():
		armor_col = Color(0.95, 0.62, 0.18)
	elif not armor.is_empty():
		armor_col = Data.items[armor["id"]]["col"] as Color
		armor_col = armor_col.darkened(0.1)
	for c in get_children():
		c.queue_free()
	_joints.clear()
	hips = _joint(self, Vector3(0, 0.98, 0), "hips")
	# pelvis
	var bp := MK.Builder.new(3)
	bp.sphere(Vector3(0.22, 0.14, 0.15), PANTS, Vector3(0, 0.0, 0))
	bp.box(Vector3(0.40, 0.07, 0.28), Color(0.45, 0.32, 0.20), Vector3(0, 0.1, 0))
	_mi(bp, hips)
	torso = _joint(hips, Vector3(0, 0.1, 0), "torso")
	var bt := MK.Builder.new(4)
	bt.sphere(Vector3(0.25, 0.33, 0.17), armor_col, Vector3(0, 0.28, 0), Vector3.ZERO, 6, 10)
	bt.box(Vector3(0.40, 0.10, 0.04), JACKET_TRIM, Vector3(0, 0.38, -0.155))
	bt.box(Vector3(0.05, 0.40, 0.03), JACKET_TRIM.darkened(0.2), Vector3(0, 0.26, -0.165))
	bt.cyl(0.09, 0.08, 0.1, SKIN, Vector3(0, 0.56, 0), Vector3.ZERO, 7)
	bt.sphere(Vector3(0.30, 0.1, 0.20), armor_col.lightened(0.1), Vector3(0, 0.50, 0.0))
	if not armor.is_empty() and String(armor["id"]) != "hide_armor":
		bt.sphere(Vector3(0.12, 0.08, 0.12), armor_col.lightened(0.25), Vector3(-0.29, 0.52, 0))
		bt.sphere(Vector3(0.12, 0.08, 0.12), armor_col.lightened(0.25), Vector3(0.29, 0.52, 0))
	_mi(bt, torso)
	# backpack
	back_node = _joint(torso, Vector3(0, 0.28, 0.2), "back")
	var bb := MK.Builder.new(5)
	var big := Game.equip.has("pack")
	var pc := Color(0.55, 0.40, 0.22) if not big else (Data.items[Game.equip["pack"]["id"]]["col"] as Color)
	var pw := 0.30 if not big else 0.36
	var ph := 0.38 if not big else 0.50
	bb.box(Vector3(pw, ph, 0.18), pc, Vector3(0, 0.0, 0.04))
	bb.box(Vector3(pw * 0.8, 0.12, 0.2), pc.darkened(0.15), Vector3(0, ph * 0.5 + 0.02, 0.04))
	bb.cyl(0.07, 0.07, pw + 0.04, Color(0.7, 0.7, 0.7), Vector3(-pw * 0.5 - 0.02, -ph * 0.5, 0.05), Vector3(0, 0, 90), 6)
	_mi(bb, back_node)
	head = _joint(torso, Vector3(0, 0.66, 0), "head")
	var bh := MK.Builder.new(6)
	bh.sphere(Vector3(0.14, 0.16, 0.15), SKIN, Vector3(0, 0.1, 0), Vector3.ZERO, 6, 10)
	bh.sphere(Vector3(0.155, 0.12, 0.165), HAIR, Vector3(0, 0.17, 0.02), Vector3.ZERO, 5, 9)
	bh.box(Vector3(0.30, 0.07, 0.04), Color(0.12, 0.14, 0.18), Vector3(0, 0.12, -0.125))
	bh.box(Vector3(0.26, 0.04, 0.03), Color(0.35, 0.85, 0.95), Vector3(0, 0.12, -0.14))
	bh.box(Vector3(0.34, 0.025, 0.04), Color(0.2, 0.2, 0.25), Vector3(0, 0.13, 0.0))
	_mi(bh, head)
	for s in [-1, 1]:
		var key := "l" if s < 0 else "r"
		var sh := _joint(torso, Vector3(0.30 * s, 0.50, 0), "sh_" + key)
		var ba := MK.Builder.new(7 + s)
		ba.cyl(0.065, 0.055, 0.30, armor_col.darkened(0.05), Vector3(0, -0.30, 0), Vector3.ZERO, 7)
		ba.sphere(Vector3(0.075, 0.075, 0.075), armor_col, Vector3(0, 0.0, 0))
		_mi(ba, sh)
		var el := _joint(sh, Vector3(0, -0.30, 0), "el_" + key)
		var bf := MK.Builder.new(9 + s)
		bf.cyl(0.055, 0.045, 0.28, SKIN.darkened(0.04), Vector3(0, -0.28, 0), Vector3.ZERO, 7)
		bf.cyl(0.06, 0.06, 0.08, Color(0.30, 0.30, 0.34), Vector3(0, -0.22, 0), Vector3.ZERO, 7)
		bf.sphere(Vector3(0.055, 0.055, 0.055), SKIN, Vector3(0, -0.30, 0))
		_mi(bf, el)
		if s < 0:
			sh_l = sh
			el_l = el
		else:
			sh_r = sh
			el_r = el
			hand_r = _joint(el, Vector3(0, -0.30, 0), "hand_r")
			hand_r.rotation.x = -1.35
	for s in [-1, 1]:
		var key := "l" if s < 0 else "r"
		var hp := _joint(hips, Vector3(0.11 * s, -0.04, 0), "hp_" + key)
		var bl := MK.Builder.new(11 + s)
		bl.cyl(0.095, 0.075, 0.46, PANTS, Vector3(0, -0.46, 0), Vector3.ZERO, 7)
		_mi(bl, hp)
		var kn := _joint(hp, Vector3(0, -0.46, 0), "kn_" + key)
		var bs := MK.Builder.new(13 + s)
		bs.cyl(0.075, 0.06, 0.40, PANTS.darkened(0.05), Vector3(0, -0.40, 0), Vector3.ZERO, 7)
		bs.cyl(0.085, 0.08, 0.16, BOOT, Vector3(0, -0.40, 0), Vector3.ZERO, 7)
		bs.box(Vector3(0.13, 0.09, 0.26), BOOT, Vector3(0, -0.42, -0.05))
		_mi(bs, kn)
		if s < 0:
			hp_l = hp
			kn_l = kn
		else:
			hp_r = hp
			kn_r = kn
	_pose.clear()


func rebuild_equipment() -> void:
	_build()
	if weapon_node and is_instance_valid(weapon_node):
		weapon_node.queue_free()
	weapon_node = null
	var id := _held_item_id()
	if id != "":
		weapon_node = _make_held(id)
		hand_r.add_child(weapon_node)


var held_override: String = ""


func _held_item_id() -> String:
	if held_override != "":
		return held_override
	if Game.equip.has("weapon"):
		return str(Game.equip["weapon"]["id"])
	return ""


func set_held(id: String) -> void:
	if id == held_override:
		return
	held_override = id
	if weapon_node and is_instance_valid(weapon_node):
		weapon_node.queue_free()
		weapon_node = null
	var hid := _held_item_id()
	if hid != "":
		weapon_node = _make_held(hid)
		hand_r.add_child(weapon_node)


func _make_held(id: String) -> Node3D:
	var it: Dictionary = Data.items[id]
	var b := MK.Builder.new(hash(id))
	b.jitter = 0.03
	var col: Color = it["col"]
	var glow := 0.0
	match String(it.get("style", it.get("tool", ""))):
		"spear":
			b.cyl(0.025, 0.02, 1.7, Color(0.55, 0.38, 0.22), Vector3(0, -0.3, 0), Vector3.ZERO, 6)
			b.cone(0.06, 0.28, Color(0.75, 0.78, 0.82), Vector3(0, 1.4, 0), Vector3.ZERO, 6)
		"blade":
			var bc := col
			b.cyl(0.03, 0.03, 0.22, Color(0.35, 0.22, 0.12), Vector3(0, -0.1, 0), Vector3.ZERO, 6)
			b.box(Vector3(0.2, 0.04, 0.06), Color(0.55, 0.5, 0.4), Vector3(0, 0.13, 0))
			b.box(Vector3(0.07, 0.8, 0.02), bc, Vector3(0, 0.55, 0))
			b.cone(0.045, 0.14, bc.lightened(0.2), Vector3(0, 0.95, 0), Vector3(0, 0, 0), 4)
			if id == "energy_blade" or id == "magma_blade" or id == "thorn_edge":
				glow = 0.6
		"ranged":
			b.box(Vector3(0.12, 0.16, 0.7), Color(0.30, 0.32, 0.38), Vector3(0, 0.1, 0.0), Vector3(90, 0, 0))
			b.cyl(0.05, 0.05, 0.5, Color(0.5, 0.85, 1.0), Vector3(0, 0.35, 0), Vector3.ZERO, 6)
			b.sphere(Vector3(0.09, 0.09, 0.09), Color(0.4, 0.9, 1.0), Vector3(0, 0.88, 0))
			glow = 0.7
		"axe":
			b.cyl(0.03, 0.025, 0.85, Color(0.55, 0.38, 0.22), Vector3(0, -0.2, 0), Vector3.ZERO, 6)
			b.box(Vector3(0.28, 0.18, 0.05), col, Vector3(0.1, 0.62, 0))
		"pick":
			b.cyl(0.03, 0.025, 0.85, Color(0.55, 0.38, 0.22), Vector3(0, -0.2, 0), Vector3.ZERO, 6)
			b.box(Vector3(0.5, 0.06, 0.05), col, Vector3(0, 0.64, 0), Vector3(0, 0, 8))
		_:
			b.box(Vector3(0.05, 0.4, 0.05), col, Vector3(0, 0.2, 0))
	var holder := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit(MK.style_material(0.0, 0.35, glow))
	holder.add_child(mi)
	return holder


# ---------------------------------------------------------------- animation
func _target_pose(delta: float) -> Dictionary:
	_t += delta
	var p := {}
	var walk_amp := clampf(speed01 * 1.1, 0.0, 1.2)
	_gait += delta * lerpf(5.0, 12.5, clampf(speed01, 0.0, 1.0)) * (1.0 if speed01 > 0.05 else 0.0)
	var g := _gait
	var s := sin(g)
	var c := cos(g)
	var breathe := sin(_t * 2.0) * 0.02
	# defaults: standing
	p["hips_y"] = 0.98 + absf(c) * 0.03 * walk_amp
	p["hips_rx"] = 0.0
	p["hips_rz"] = 0.0
	p["torso_rx"] = breathe + speed01 * 0.22
	p["torso_ry"] = 0.0
	p["head_rx"] = -speed01 * 0.1
	p["sh_l"] = Vector3(-s * 0.7 * walk_amp, 0, 0.08)
	p["sh_r"] = Vector3(s * 0.7 * walk_amp, 0, -0.08)
	p["el_l"] = Vector3(-0.2 - maxf(0.0, -s) * 0.4 * walk_amp, 0, 0)
	p["el_r"] = Vector3(-0.2 - maxf(0.0, s) * 0.4 * walk_amp, 0, 0)
	p["hp_l"] = Vector3(s * 0.8 * walk_amp, 0, 0.03)
	p["hp_r"] = Vector3(-s * 0.8 * walk_amp, 0, -0.03)
	p["kn_l"] = Vector3(maxf(0.0, -s) * 1.1 * walk_amp + 0.05, 0, 0)
	p["kn_r"] = Vector3(maxf(0.0, s) * 1.1 * walk_amp + 0.05, 0, 0)
	if speed01 < 0.05 and state == "idle":
		p["sh_l"] = Vector3(0.05 + breathe, 0, 0.1)
		p["sh_r"] = Vector3(0.05 - breathe, 0, -0.1)
	# held weapon posture while moving/idle
	if weapon_node != null and state in ["idle", "move"]:
		p["sh_r"] = Vector3(0.5 + (s * 0.35 * walk_amp), 0, -0.12)
		p["el_r"] = Vector3(-1.1, 0, 0)
	match state:
		"jump":
			p["hp_l"] = Vector3(-0.7, 0, 0.1)
			p["hp_r"] = Vector3(-0.2, 0, -0.1)
			p["kn_l"] = Vector3(1.2, 0, 0)
			p["kn_r"] = Vector3(0.6, 0, 0)
			p["sh_l"] = Vector3(-2.3, 0, 0.3)
			p["sh_r"] = Vector3(-2.3, 0, -0.3)
			p["torso_rx"] = -0.05
		"fall":
			p["hp_l"] = Vector3(0.25, 0, 0.35)
			p["hp_r"] = Vector3(-0.2, 0, -0.35)
			p["kn_l"] = Vector3(0.4, 0, 0)
			p["kn_r"] = Vector3(0.4, 0, 0)
			p["sh_l"] = Vector3(-0.6, 0, 1.0)
			p["sh_r"] = Vector3(-0.6, 0, -1.0)
		"land":
			p["hips_y"] = 0.78
			p["hp_l"] = Vector3(1.0, 0, 0.15)
			p["hp_r"] = Vector3(1.0, 0, -0.15)
			p["kn_l"] = Vector3(1.6, 0, 0)
			p["kn_r"] = Vector3(1.6, 0, 0)
			p["torso_rx"] = 0.5
		"swim":
			var sw := sin(_t * 5.0)
			p["hips_y"] = 0.62
			p["hips_rx"] = 1.15
			p["sh_l"] = Vector3(-1.8 + sw * 1.2, 0, 0.3)
			p["sh_r"] = Vector3(-1.8 - sw * 1.2, 0, -0.3)
			p["el_l"] = Vector3(-0.3, 0, 0)
			p["el_r"] = Vector3(-0.3, 0, 0)
			p["hp_l"] = Vector3(sw * 0.5, 0, 0)
			p["hp_r"] = Vector3(-sw * 0.5, 0, 0)
			p["kn_l"] = Vector3(0.3, 0, 0)
			p["kn_r"] = Vector3(0.3, 0, 0)
			p["torso_rx"] = -0.5
		"dodge":
			var f := clampf(phase_t / maxf(action_len, 0.01), 0.0, 1.0)
			p["hips_y"] = 0.72
			p["hips_rx"] = f * TAU
			p["hp_l"] = Vector3(1.5, 0, 0.1)
			p["hp_r"] = Vector3(1.5, 0, -0.1)
			p["kn_l"] = Vector3(2.0, 0, 0)
			p["kn_r"] = Vector3(2.0, 0, 0)
			p["sh_l"] = Vector3(-1.2, 0, 0.3)
			p["sh_r"] = Vector3(-1.2, 0, -0.3)
			p["torso_rx"] = 0.7
		"hurt":
			p["torso_rx"] = -0.45
			p["head_rx"] = -0.35
			p["sh_l"] = Vector3(-0.5, 0, 0.9)
			p["sh_r"] = Vector3(-0.5, 0, -0.9)
		"death":
			var f2 := smoothstep(0.0, 0.7, clampf(phase_t, 0.0, 1.0))
			p["hips_rx"] = -f2 * 1.5
			p["hips_y"] = lerpf(0.98, 0.18, f2)
			p["sh_l"] = Vector3(-0.5, 0, 1.2 * f2)
			p["sh_r"] = Vector3(-0.5, 0, -1.2 * f2)
		"sleep":
			p["hips_rx"] = -1.5
			p["hips_y"] = 0.25
		"interact":
			var f3 := sin(clampf(phase_t / maxf(action_len, 0.01), 0.0, 1.0) * PI)
			p["sh_r"] = Vector3(-1.2 * f3, 0, -0.1)
			p["el_r"] = Vector3(-0.6 * f3, 0, 0)
			p["torso_rx"] = 0.15 * f3
		"gather":
			_pose_gather(p)
		"attack":
			_pose_attack(p)
	if crouch and state in ["idle", "move"]:
		p["hips_y"] = 0.78
		p["torso_rx"] = float(p["torso_rx"]) + 0.35
		p["kn_l"] = Vector3(float((p["kn_l"] as Vector3).x) + 0.9, 0, 0)
		p["kn_r"] = Vector3(float((p["kn_r"] as Vector3).x) + 0.9, 0, 0)
		p["hp_l"] = Vector3(float((p["hp_l"] as Vector3).x) + 0.5, 0, 0)
		p["hp_r"] = Vector3(float((p["hp_r"] as Vector3).x) + 0.5, 0, 0)
	return p


func _pose_gather(p: Dictionary) -> void:
	var f := clampf(phase_t / maxf(action_len, 0.01), 0.0, 1.0)
	match action_kind:
		"pluck":
			var d := sin(f * PI)
			p["torso_rx"] = 0.9 * d
			p["hips_y"] = 0.9 - 0.12 * d
			p["sh_r"] = Vector3(-0.2 * d, 0, -0.2)
			p["sh_l"] = Vector3(-0.2 * d, 0, 0.2)
			p["hp_l"] = Vector3(0.3 * d, 0, 0)
			p["hp_r"] = Vector3(0.3 * d, 0, 0)
		"mine":
			var up := smoothstep(0.0, 0.35, f)
			var dn := smoothstep(0.35, 0.55, f)
			var ang := lerpf(-2.5 * up, 0.2, dn)
			p["sh_r"] = Vector3(ang, 0, -0.1)
			p["sh_l"] = Vector3(ang, 0, 0.1)
			p["el_r"] = Vector3(-0.3, 0, 0)
			p["torso_rx"] = 0.25 * dn - 0.12 * up
		_:   # chop
			var up2 := smoothstep(0.0, 0.4, f)
			var dn2 := smoothstep(0.4, 0.58, f)
			var ang2 := lerpf(-2.6 * up2, 0.3, dn2)
			p["sh_r"] = Vector3(ang2, 0, -0.35 * (1.0 - dn2))
			p["sh_l"] = Vector3(ang2 * 0.9, 0, 0.3)
			p["el_r"] = Vector3(-0.4, 0, 0)
			p["torso_ry"] = 0.35 * (up2 - dn2)
			p["torso_rx"] = 0.28 * dn2 - 0.1 * up2
	p["hp_l"] = Vector3(0.35, 0, 0.1)
	p["hp_r"] = Vector3(-0.3, 0, -0.1)
	p["kn_l"] = Vector3(0.4, 0, 0)
	p["kn_r"] = Vector3(0.4, 0, 0)


func _pose_attack(p: Dictionary) -> void:
	var f := clampf(phase_t / maxf(action_len, 0.01), 0.0, 1.0)
	var wind := smoothstep(0.0, 0.3, f)
	var strike := smoothstep(0.3, 0.5, f)
	var recov := smoothstep(0.62, 1.0, f)
	var k := action_kind
	p["hp_l"] = Vector3(0.55, 0, 0.12)
	p["hp_r"] = Vector3(-0.45, 0, -0.12)
	p["kn_l"] = Vector3(0.5, 0, 0)
	p["kn_r"] = Vector3(0.45, 0, 0)
	if k == "thrust":
		var back := wind * (1.0 - strike)
		p["sh_r"] = Vector3(lerpf(0.4, 1.35, strike) * (1.0 - recov) + 0.5 * recov, 0, -0.1)
		p["el_r"] = Vector3(-1.3 * back - 0.1, 0, 0)
		p["sh_l"] = Vector3(0.9 * (1.0 - recov), 0, 0.3)
		p["torso_rx"] = 0.35 * strike * (1.0 - recov)
		p["torso_ry"] = -0.3 * wind * (1.0 - strike)
		p["hips_y"] = 0.92
	elif k == "shoot":
		p["sh_r"] = Vector3(1.4, 0, -0.1)
		p["el_r"] = Vector3(-0.15 - 0.3 * (1.0 - strike), 0, 0)
		p["sh_l"] = Vector3(1.2, 0, 0.45)
		p["torso_ry"] = -0.35
		p["torso_rx"] = -0.1 * (1.0 - strike)
	elif k == "heavy":
		var hw := smoothstep(0.0, 0.45, f)
		var hs := smoothstep(0.45, 0.6, f)
		p["sh_r"] = Vector3(lerpf(-2.7 * hw, 0.5, hs), 0, -0.3 * (1.0 - hs))
		p["sh_l"] = Vector3(lerpf(-2.5 * hw, 0.3, hs), 0, 0.3)
		p["el_r"] = Vector3(-0.4, 0, 0)
		p["torso_rx"] = lerpf(-0.3 * hw, 0.55, hs) * (1.0 - recov)
		p["hips_y"] = 0.86
	else:
		# horizontal / diagonal slashes, alternating sides
		var dir := 1.0
		var pitch := 1.2
		if k == "swing2":
			dir = -1.0
			pitch = 0.9
		elif k == "swing3":
			dir = 1.0
			pitch = 1.8
		var a := lerpf(-0.9 * wind, 1.3, strike)
		p["sh_r"] = Vector3(lerpf(0.4 + 0.9 * wind, pitch, strike) * (1.0 - recov) + 0.5 * recov, 0.0, lerpf(-1.1 * dir * wind, 0.9 * dir, strike) * (1.0 - recov))
		p["el_r"] = Vector3(-0.6 + 0.4 * strike, 0, 0)
		p["sh_l"] = Vector3(0.4, 0, 0.5)
		p["torso_ry"] = lerpf(0.6 * dir * wind, -0.6 * dir, strike) * (1.0 - recov)
		p["torso_rx"] = 0.2 * strike * (1.0 - recov)
		p["hips_y"] = 0.93
		a = a


func animate(delta: float) -> void:
	var tgt := _target_pose(delta)
	var k := clampf(delta * (22.0 if state in ["attack", "dodge"] else 14.0), 0.0, 1.0)
	for key in tgt:
		var tv: Variant = tgt[key]
		if not _pose.has(key):
			_pose[key] = tv
		else:
			_pose[key] = lerp(_pose[key], tv, k)
	hips.position.y = float(_pose["hips_y"])
	hips.rotation = Vector3(float(_pose["hips_rx"]), 0, float(_pose["hips_rz"]))
	torso.rotation = Vector3(float(_pose["torso_rx"]), float(_pose["torso_ry"]), 0)
	head.rotation = Vector3(float(_pose["head_rx"]), -float(_pose["torso_ry"]) * 0.5, 0)
	sh_l.rotation = _pose["sh_l"]
	sh_r.rotation = _pose["sh_r"]
	el_l.rotation = _pose["el_l"]
	el_r.rotation = _pose["el_r"]
	hp_l.rotation = _pose["hp_l"]
	hp_r.rotation = _pose["hp_r"]
	kn_l.rotation = _pose["kn_l"]
	kn_r.rotation = _pose["kn_r"]
	# keep the root offset when swimming so the body lies on the surface
	position.y = 0.0
