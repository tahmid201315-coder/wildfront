extends "res://scripts/world/interactable.gd"
## Dropped item stack on the ground (pack overflow, death cache, loot).

var item_id: String = ""
var amount: int = 1
var life: float = 600.0
var mesh: MeshInstance3D
var t: float = 0.0


func setup(id: String, n: int) -> void:
	item_id = id
	amount = n
	interact_radius = 2.0
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.18
	sm.height = 0.36
	var mat := StandardMaterial3D.new()
	var col: Color = Data.items[id].get("col", Color(0.8, 0.8, 0.8)) as Color
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 0.6
	sm.material = mat
	m.mesh = sm
	m.position.y = 0.4
	add_child(m)
	mesh = m


func get_prompt(_p: Node) -> String:
	return "Pick up %d x %s" % [amount, Data.item_name(item_id)]


func interact(_p: Node) -> void:
	var left := Inv.add(item_id, amount)
	if left < amount:
		Sfx.play("pickup")
		Game.toast("+%d %s" % [amount - left, Data.item_name(item_id)], "item")
	if left <= 0:
		queue_free()
	else:
		amount = left
		Game.toast("Pack is full.", "warn")


func _process(delta: float) -> void:
	t += delta
	if mesh:
		mesh.position.y = 0.4 + sin(t * 2.5) * 0.06
	life -= delta
	if life <= 0.0:
		queue_free()
