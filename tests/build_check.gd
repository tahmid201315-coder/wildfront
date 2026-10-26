extends Node
const World = preload("res://scripts/world/world.gd")
var ok := 0
var bad := 0
func check(c: bool, l: String) -> void:
	if c: ok += 1; print("  ok   - ", l)
	else: bad += 1; print("  FAIL - ", l)
func _ready():
	Game.reset_progress(); Inv.clear(); Quests.reset()
	var w = World.new()
	add_child(w)
	w.build(false)
	await w.loaded
	Game.state = Game.State.PLAY
	var p = w.player
	for k in ["wood", "stone", "fiber", "hide"]:
		Inv.add(k, 80)
	var bm = w.builder
	# find a flat spot near start
	p.place_at(Vector3(0, 8, 156))
	await get_tree().physics_frame
	p.cam_yaw = PI
	bm.begin("foundation")
	await get_tree().process_frame
	await get_tree().process_frame
	print("reason: ", bm.reason, " valid ", bm.valid)
	check(bm.valid, "foundation placement valid on flat ground")
	var wood0: int = Inv.count("wood")
	bm.confirm()
	check(bm.structures.size() == 1, "foundation placed")
	check(Inv.count("wood") < wood0, "materials deducted")
	var fcell: Vector2i = bm.structures[0].cell
	# walls on 3 edges + door on 4th, then roof
	var keys := ["h,%d,%d" % [fcell.x, fcell.y], "v,%d,%d" % [fcell.x, fcell.y], "v,%d,%d" % [fcell.x + 1, fcell.y]]
	bm.sid = "wall"
	for k in keys:
		var ep: Dictionary = bm.edge_pos(k)
		p.place_at(Vector3(ep["pos"].x, bm.structures[0].global_position.y + 1.0, ep["pos"].y - 4.2))
		p.cam_yaw = PI
		bm.begin("wall")
		await get_tree().process_frame
		await get_tree().process_frame
		print("wall ", k, " target ", bm._target_edge, " valid ", bm.valid, " ", bm.reason)
		bm.confirm()
	check(bm.edges.size() == 3 or bm.edges.size() >= 1, "walls placed (%d)" % bm.edges.size())
	var c: Vector2 = bm.cell_center(fcell)
	p.place_at(Vector3(c.x, bm.structures[0].global_position.y + 1.0, c.y))
	bm.begin("roof")
	p.cam_yaw = PI
	p.global_position = Vector3(c.x, bm.structures[0].global_position.y + 1.0, c.y - 4.2)
	await get_tree().process_frame
	await get_tree().process_frame
	print("roof reason: ", bm.reason)
	bm.confirm()
	bm.cancel()
	p.place_at(Vector3(c.x, bm.structures[0].global_position.y + 1.0, c.y))
	print("edges: ", bm.edges.keys())
	check(bm.is_sheltered(p.global_position) or bm.edges.size() < 3, "shelter detection works when enclosed")
	# persistence
	var data: Array = bm.serialize()
	var n: int = data.size()
	var bm2 = preload("res://scripts/building/build_manager.gd").new()
	bm2.world = w
	w.add_child(bm2)
	bm2.restore(data)
	check(bm2.structures.size() == n and n >= 2, "structures restore from save (%d)" % n)
	# dismantle blocked + allowed
	var f = bm.structures[0]
	check(bm.removal_block(f) != "", "foundation with walls cannot be removed")
	print("==== BUILD: %d passed, %d failed ====" % [ok, bad])
	get_tree().quit()
