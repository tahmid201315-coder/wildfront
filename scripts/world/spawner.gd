extends Node
## Places enemy dens and wildlife herds across the island and streams them in/out around the player.

const WG = preload("res://scripts/world/world_gen.gd")
const DW = preload("res://scripts/core/data_world.gd")
const Enemy = preload("res://scripts/enemies/enemy.gd")
const Animal = preload("res://scripts/enemies/animal.gd")

const SPAWN_R := 85.0
const DESPAWN_R := 115.0
const DEN_RESPAWN := 540.0

var world: Node3D
var dens: Array = []        # {id, kind:"enemy"/"animal", type, pos, count, cleared_at (play_seconds, -1 = alive), nodes[]}
var _acc: float = 0.0

# [region, type, count of dens, enemies per den (min,max)]
const ENEMY_PLAN := [
	["coast", "stalker", 3, 1, 2], ["forest", "stalker", 15, 1, 3], ["forest", "brute", 3, 1, 1],
	["highlands", "brute", 8, 1, 2], ["highlands", "sentinel", 6, 1, 1], ["highlands", "wraith", 5, 1, 2],
	["ashen", "wraith", 7, 1, 2], ["ashen", "sentinel", 6, 1, 2], ["ashen", "brute", 3, 1, 1],
	["core", "wraith", 6, 1, 2], ["core", "sentinel", 8, 1, 2],
]
const ANIMAL_PLAN := [
	["coast", "crab", 14, 2, 3], ["coast", "mossdeer", 4, 2, 3], ["forest", "mossdeer", 14, 2, 4],
	["highlands", "ridge_goat", 10, 2, 3], ["ashen", "ember_newt", 8, 2, 3],
]


func generate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9001
	var n := 0
	for plan in ENEMY_PLAN:
		_place(plan, "enemy", rng, n)
		n += int(plan[2])
	for plan in ANIMAL_PLAN:
		_place(plan, "animal", rng, n)
		n += int(plan[2])


func _place(plan: Array, kind: String, rng: RandomNumberGenerator, base_id: int) -> void:
	var reg: String = plan[0]
	var placed := 0
	var tries := 0
	var start := Vector2(DW.START_POS.x, DW.START_POS.y)
	while placed < int(plan[2]) and tries < 4000:
		tries += 1
		var rc: Vector2 = DW.REGIONS[reg]["center"]
		var rr: float = DW.REGIONS[reg]["radius"]
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * rr
		var p := rc + Vector2(cos(a), sin(a)) * d
		if absf(p.x) > 240 or absf(p.y) > 240:
			continue
		if WG.region_at(p.x, p.y) != reg:
			continue
		var h := WG.height_at(p.x, p.y)
		if h < 1.2 or WG.slope_at(p.x, p.y) > 0.5:
			continue
		if kind == "enemy" and p.distance_to(start) < 70.0:
			continue
		if kind == "animal" and reg == "coast" and plan[1] == "crab" and h > 4.0:
			continue
		var bad := false
		for s in DW.SITES.values():
			if p.distance_to(s["pos"]) < float(s["flat"]) + (14.0 if kind == "enemy" else 6.0):
				bad = true
				break
		if bad:
			continue
		for o in dens:
			if o["pos"].distance_to(p) < 22.0 and o["kind"] == kind:
				bad = true
				break
		if bad:
			continue
		dens.append({"id": base_id + placed, "kind": kind, "type": plan[1], "pos": p, "count": rng.randi_range(int(plan[3]), int(plan[4])), "cleared_at": -1.0, "nodes": [], "y": h})
		placed += 1


func add_den(kind: String, type: String, pos: Vector2, count: int) -> void:
	dens.append({"id": 1000 + dens.size(), "kind": kind, "type": type, "pos": pos, "count": count, "cleared_at": -1.0, "nodes": [], "y": WG.height_at(pos.x, pos.y)})


func _process(delta: float) -> void:
	_acc += delta
	if _acc < 0.5 or world == null or world.player == null or not Game.is_playing():
		return
	_acc = 0.0
	var pp: Vector3 = world.player.global_position
	var p2 := Vector2(pp.x, pp.z)
	for d in dens:
		var dist: float = d["pos"].distance_to(p2)
		var alive_nodes: Array = []
		for n in d["nodes"]:
			if is_instance_valid(n) and n.alive:
				alive_nodes.append(n)
		d["nodes"] = alive_nodes
		if d["cleared_at"] >= 0.0:
			if Game.play_seconds - float(d["cleared_at"]) > DEN_RESPAWN and dist > 60.0:
				d["cleared_at"] = -1.0
			continue
		if dist < SPAWN_R and d["nodes"].is_empty() and not d.get("spawned", false):
			_spawn(d)
		elif dist > DESPAWN_R and not d["nodes"].is_empty():
			var engaged := false
			for n in d["nodes"]:
				if n.has_method("is_engaged") and n.is_engaged():
					engaged = true
			if not engaged:
				for n in d["nodes"]:
					_remove(n)
				d["nodes"] = []
				d["spawned"] = false
		elif d.get("spawned", false) and d["nodes"].is_empty():
			d["cleared_at"] = Game.play_seconds
			d["spawned"] = false


func _remove(n: Node) -> void:
	if n is Enemy:
		world.enemies.erase(n)
	else:
		world.animals.erase(n)
	n.queue_free()


func _spawn(d: Dictionary) -> void:
	d["spawned"] = true
	for i in int(d["count"]):
		var off := Vector2(randf_range(-4, 4), randf_range(-4, 4))
		var p: Vector2 = d["pos"] + off
		var h := WG.height_at(p.x, p.y)
		if h < 0.8:
			continue
		var pos := Vector3(p.x, h + 0.3, p.y)
		if d["kind"] == "enemy":
			var e := Enemy.new()
			world.add_child(e)
			e.setup(String(d["type"]), Data.enemies[d["type"]], Vector3(d["pos"].x, d["y"], d["pos"].y))
			e.global_position = pos
			world.enemies.append(e)
			d["nodes"].append(e)
		else:
			var a := Animal.new()
			world.add_child(a)
			a.setup(String(d["type"]), Data.animals[d["type"]], pos)
			world.animals.append(a)
			d["nodes"].append(a)
	if d["nodes"].is_empty():
		d["cleared_at"] = Game.play_seconds - DEN_RESPAWN + 30.0


func serialize() -> Array:
	var out: Array = []
	for d in dens:
		if d["cleared_at"] >= 0.0:
			out.append([d["id"], maxf(DEN_RESPAWN - (Game.play_seconds - float(d["cleared_at"])), 1.0)])
	return out


func restore(arr: Array) -> void:
	var byid := {}
	for d in dens:
		byid[d["id"]] = d
	for e in arr:
		var id := int(e[0])
		if byid.has(id):
			byid[id]["cleared_at"] = Game.play_seconds - (DEN_RESPAWN - float(e[1]))
