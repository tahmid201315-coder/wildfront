extends Node3D
## Procedural stylized explorer model with the ten required animation states.
## Replace this node with an imported character; keep set_anim(state) / update_anim(delta, speed)
## on the replacement and the gameplay code does not need to change.

const CM = preload("res://scripts/creatures/creature_model.gd")

const STATES := ["idle", "walk", "run", "jump", "fall", "land", "gather", "interact", "celebrate", "rest"]

var anim: String = "idle"
var _t: float = 0.0
var rig: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var head: Node3D
var torso: Node3D


func _ready() -> void:
	var skin := Color(0.94, 0.76, 0.6)
	var shirt := Color(0.18, 0.62, 0.62)
	var pants := Color(0.25, 0.28, 0.4)
	var hair := Color(0.25, 0.15, 0.1)
	rig = Node3D.new()
	add_child(rig)
	torso = Node3D.new()
	torso.position = Vector3(0, 0.95, 0)
	rig.add_child(torso)
	CM.part(torso, "sphere", Vector3(0.55, 0.7, 0.36), shirt, Vector3(0, 0.0, 0))
	CM.part(torso, "box", Vector3(0.5, 0.18, 0.38), Color(0.6, 0.4, 0.2), Vector3(0, -0.25, 0))
	CM.part(torso, "box", Vector3(0.42, 0.5, 0.2), Color(0.8, 0.5, 0.25), Vector3(0, 0.05, 0.27))
	head = Node3D.new()
	head.position = Vector3(0, 0.62, 0)
	torso.add_child(head)
	CM.part(head, "sphere", Vector3(0.38, 0.4, 0.38), skin, Vector3.ZERO)
	CM.part(head, "sphere", Vector3(0.42, 0.28, 0.42), hair, Vector3(0, 0.1, 0.03))
	for s in [-1, 1]:
		CM.part(head, "sphere", Vector3(0.06, 0.06, 0.06), Color(0.1, 0.1, 0.12), Vector3(0.08 * s, 0.02, -0.17))
	arm_l = Node3D.new()
	arm_l.position = Vector3(-0.34, 0.25, 0)
	torso.add_child(arm_l)
	CM.part(arm_l, "cyl", Vector3(0.13, 0.55, 0.13), shirt.darkened(0.1), Vector3(0, -0.25, 0))
	CM.part(arm_l, "sphere", Vector3(0.14, 0.14, 0.14), skin, Vector3(0, -0.55, 0))
	arm_r = Node3D.new()
	arm_r.position = Vector3(0.34, 0.25, 0)
	torso.add_child(arm_r)
	CM.part(arm_r, "cyl", Vector3(0.13, 0.55, 0.13), shirt.darkened(0.1), Vector3(0, -0.25, 0))
	CM.part(arm_r, "sphere", Vector3(0.14, 0.14, 0.14), skin, Vector3(0, -0.55, 0))
	leg_l = Node3D.new()
	leg_l.position = Vector3(-0.14, 0.62, 0)
	rig.add_child(leg_l)
	CM.part(leg_l, "cyl", Vector3(0.17, 0.62, 0.17), pants, Vector3(0, -0.3, 0))
	CM.part(leg_l, "box", Vector3(0.18, 0.1, 0.28), Color(0.3, 0.2, 0.15), Vector3(0, -0.62, -0.04))
	leg_r = Node3D.new()
	leg_r.position = Vector3(0.14, 0.62, 0)
	rig.add_child(leg_r)
	CM.part(leg_r, "cyl", Vector3(0.17, 0.62, 0.17), pants, Vector3(0, -0.3, 0))
	CM.part(leg_r, "box", Vector3(0.18, 0.1, 0.28), Color(0.3, 0.2, 0.15), Vector3(0, -0.62, -0.04))


func set_anim(state: String) -> void:
	if state in STATES:
		anim = state


func update_anim(delta: float, speed: float) -> void:
	_t += delta
	var swing := 0.0
	var freq := 8.0
	var lean := 0.0
	var body_y := 0.0
	var ar := 0.0
	var al := 0.0
	var lr := 0.0
	var ll := 0.0
	match anim:
		"walk":
			swing = 0.7
			freq = 9.0
			ar = sin(_t * freq) * swing
			al = -ar
			lr = -ar * 0.9
			ll = ar * 0.9
			body_y = absf(sin(_t * freq)) * 0.04
		"run":
			swing = 1.1
			freq = 13.0
			ar = sin(_t * freq) * swing
			al = -ar
			lr = -ar
			ll = ar
			lean = 0.22
			body_y = absf(sin(_t * freq)) * 0.07
		"jump":
			ar = -2.4
			al = -2.4
			lr = 0.4
			ll = -0.3
		"fall":
			ar = -0.9
			al = -0.9
			lr = 0.3
			ll = -0.3
			lean = 0.05
		"land":
			body_y = -0.15
			ar = 0.4
			al = 0.4
			lr = -0.5
			ll = -0.5
		"gather":
			ar = -1.3 + sin(_t * 11.0) * 1.0
			al = -0.5
			lean = 0.2
		"interact":
			ar = -1.5
			al = 0.1
		"celebrate":
			ar = -2.8 + sin(_t * 12.0) * 0.3
			al = -2.8 - sin(_t * 12.0) * 0.3
			body_y = absf(sin(_t * 8.0)) * 0.2
		"rest":
			body_y = -0.38
			lr = -1.4
			ll = -1.4
			ar = 0.3
			al = 0.3
			lean = 0.1
		_:
			ar = sin(_t * 1.8) * 0.04
			al = -ar
			body_y = sin(_t * 1.8) * 0.01
	rig.position.y = lerpf(rig.position.y, body_y, minf(1.0, delta * 18.0))
	torso.rotation.x = lerpf(torso.rotation.x, -lean, minf(1.0, delta * 12.0))
	arm_r.rotation.x = lerpf(arm_r.rotation.x, ar, minf(1.0, delta * 20.0))
	arm_l.rotation.x = lerpf(arm_l.rotation.x, al, minf(1.0, delta * 20.0))
	leg_r.rotation.x = lerpf(leg_r.rotation.x, lr, minf(1.0, delta * 20.0))
	leg_l.rotation.x = lerpf(leg_l.rotation.x, ll, minf(1.0, delta * 20.0))
