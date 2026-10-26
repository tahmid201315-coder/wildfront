extends Node
## Scripted playthrough: drives the real world, real interactables and real quest logic from a new game to the
## final quest. It uses direct API calls instead of touch input and grants crafting materials (marked below),
## so it proves the quest chain is completable and the systems connect. It is NOT a device playtest.
## Run: godot --headless --path . res://tests/playthrough.tscn

const World = preload("res://scripts/world/world.gd")
const WG = preload("res://scripts/world/world_gen.gd")
const DW = preload("res://scripts/core/data_world.gd")
const Crafting = preload("res://scripts/systems/crafting.gd")

var ok := 0
var bad := 0
var w
var p


func check(c: bool, l: String) -> void:
	if c:
		ok += 1
		print("  ok   - ", l)
	else:
		bad += 1
		print("  FAIL - ", l)


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func tp(x: float, z: float) -> void:
	p.place_at(Vector3(x, WG.height_at(x, z) + 0.6, z))


func tp_site(id: String, dx: float = 0.0, dz: float = 6.0) -> void:
	var sp: Vector2 = DW.SITES[id]["pos"]
	tp(sp.x + dx, sp.y + dz)


func find_obj(site: String, prop: String, val: String):
	var root = w.get_node_or_null("Site_" + site)
	if root == null:
		return null
	for c in root.get_children():
		if c.get(prop) != null and str(c.get(prop)) == val:
			return c
	return null


func find_class_obj(site: String, script_name: String):
	var root = w.get_node_or_null("Site_" + site)
	if root == null:
		return null
	for c in root.get_children():
		var sc = c.get_script()
		if sc and str(sc.get_global_name() if sc.has_method("get_global_name") else "") == script_name:
			return c
		if sc and sc.resource_path.ends_with("site_objects.gd") and c.get_class() == "Node3D" and c.get_script().get_instance_base_type() != "":
			pass
	return null


func level_up(n: int) -> void:
	while Game.level < n:
		Game.add_xp(500)


func gather_from(rid: String, want_stat: String, amount: int) -> void:
	var tries := 0
	while Game.stat(want_stat) < amount and tries < 60:
		tries += 1
		var best = null
		var bd := 1e9
		for r in w.resources:
			if r.rid == rid and not r.depleted:
				var d: float = r.global_position.distance_to(p.global_position)
				if d < bd:
					bd = d
					best = r
		if best == null:
			break
		tp(best.global_position.x + 1.2, best.global_position.z)
		await frames(3)
		best.start_gather(p)
		for i in 90:
			await get_tree().physics_frame
			if best.depleted:
				break


func fight_boss(bid: String) -> bool:
	var b = null
	for e in w.enemies:
		if e.get("bid") == bid:
			b = e
	if b == null:
		return false
	var c: Vector3 = b.arena_c
	tp(c.x + 14, c.z)
	for i in 60 * 60:
		await get_tree().physics_frame
		if Game.health < Game.max_health * 0.5:
			Game.health = Game.max_health
		if i > 200 and i % 120 == 0 and b.alive:
			if b.shield:
				for a in b.adds:
					if is_instance_valid(a) and a.alive:
						a.take_damage(999.0, p.global_position, 0.0, p, false)
			else:
				b.take_damage(b.max_hp * 0.14, p.global_position, 0.0, p, false)
		if not b.alive:
			break
	await frames(30)
	return not b.alive


func build_piece(sid: String, at: Vector2) -> bool:
	var before: int = w.builder.structures.size()
	tp(at.x, at.y - 5.0)
	p.cam_yaw = PI
	await frames(3)
	w.builder.begin(sid)
	await get_tree().process_frame
	await get_tree().process_frame
	w.builder.confirm()
	await get_tree().process_frame
	return w.builder.structures.size() > before


func _ready() -> void:
	Game.reset_progress()
	Inv.clear()
	Quests.reset()
	Inv.add("bandage", 2)
	Inv.add("berries", 4)
	w = World.new()
	add_child(w)
	w.build(false)
	await w.loaded
	Game.state = Game.State.PLAY
	p = w.player
	Quests.refresh(false)
	await frames(20)
	var done_log: Array = []
	Quests.quest_completed.connect(func(id): done_log.append(id))

	print("-- m01 Survive the Landing (real gathering and crafting)")
	tp(20, 150)
	await gather_from("branches", "gather:wood", 6)
	await gather_from("pebbles", "gather:stone", 3)
	check(Game.stat("gather:wood") >= 6, "gathered wood by hand (%d)" % Game.stat("gather:wood"))
	check(Game.stat("gather:stone") >= 3, "gathered stone by hand (%d)" % Game.stat("gather:stone"))
	Inv.add("fiber", 6)   # shortcut: grants fiber for the axe recipe
	Inv.add("wood", 10)
	Inv.add("stone", 10)
	check(Crafting.craft("stone_axe") == "", "crafted stone axe at no station")
	await frames(5)
	check(Quests.completed.has("m01"), "quest m01 completed")

	print("-- m02 Build a Shelter (real build manager)")
	Inv.add("wood", 60)
	Inv.add("stone", 30)
	Inv.add("fiber", 30)
	var camp_ok: bool = await build_piece("campfire", Vector2(30, 160))
	check(camp_ok, "campfire placed")
	var shelter_ok: bool = await build_piece("shelter", Vector2(44, 160))
	check(shelter_ok, "shelter placed")
	tp(44, 160)
	await frames(10)
	w.update_shelter_flag()
	await frames(10)
	check(Quests.completed.has("m02"), "quest m02 completed (campfire + shelter)")

	print("-- m03 First research log")
	level_up(11)
	tp_site("beacon", 5, 0)
	await frames(40)
	var t = find_obj("beacon", "log_id", "log_coast")
	check(t != null, "beacon log terminal exists")
	if t:
		t.interact(p)
	await frames(5)
	check(Quests.completed.has("m03"), "quest m03 completed")

	print("-- m04 Whispering Forest and outpost")
	tp(-100, 45)
	await frames(60)
	tp_site("outpost", 0, 8)
	await frames(60)
	check(Game.regions_seen.has("forest"), "forest region entered")
	check(Game.sites_found.has("outpost"), "outpost discovered by proximity")
	check(Quests.completed.has("m04"), "quest m04 completed")

	print("-- m05 outpost locker")
	var lock = find_obj("outpost", "cid", "outpost_locker")
	check(lock != null, "outpost locker exists")
	if lock:
		lock.interact(p)
	await frames(5)
	check(Inv.count("survey_kit") >= 1, "survey kit obtained from locker")
	check(Quests.completed.has("m05"), "quest m05 completed")

	print("-- m06 Facility, mine, generator")
	tp_site("mine", 0, 8)
	await frames(40)
	var ml = find_obj("mine", "cid", "mine_locker")
	if ml:
		ml.interact(p)
	check(Inv.count("power_cell") >= 1, "power cell from mine locker")
	tp_site("facility", 0, 12)
	await frames(40)
	var gen = null
	for c in w.get_node("Site_facility").get_children():
		if c.get("on") != null and c.get("lamp") != null:
			gen = c
	check(gen != null, "generator exists")
	if gen:
		gen.interact(p)
	await frames(5)
	check(Game.unlocked("facility"), "facility recipes unlocked")
	check(Quests.completed.has("m06"), "quest m06 completed")

	print("-- m07 craft Environmental Suit at a workbench")
	for k in {"iron_ingot": 5, "copper_ingot": 3, "hide": 4, "machine_part": 3, "crystal": 2, "wood": 30, "stone": 20, "fiber": 20}:
		Inv.add(k, {"iron_ingot": 5, "copper_ingot": 3, "hide": 4, "machine_part": 3, "crystal": 2, "wood": 30, "stone": 20, "fiber": 20}[k])   # shortcut: materials
	var wb_ok: bool = await build_piece("workbench", Vector2(60, 165))
	check(wb_ok, "workbench placed")
	tp(60, 162)
	await frames(10)
	check(Crafting.craft("heat_suit") == "", "heat suit crafted at workbench (station check passed)")
	await frames(5)
	check(Quests.completed.has("m07"), "quest m07 completed")

	print("-- m08 Grove Guardian")
	check(await fight_boss("grove_guardian"), "Grove Guardian defeated")
	check(Inv.count("verdant_seal") >= 1, "Verdant Seal dropped")
	check(Quests.completed.has("m08"), "quest m08 completed")

	print("-- m09 Seal gate and Ashen Expanse")
	tp_site("verdant_gate", 0, 6)
	await frames(30)
	var sg = null
	for c in w.get_node("Site_verdant_gate").get_children():
		if c.get("gate_id") == "verdant_gate":
			sg = c
	check(sg != null, "seal gate exists")
	if sg:
		sg.interact(p)
	check(Game.flag("gate_verdant_gate"), "seal gate opened with the seal")
	tp(105, -90)
	await frames(60)
	check(Game.regions_seen.has("ashen"), "ashen region entered")
	check(Quests.completed.has("m09"), "quest m09 completed")

	print("-- m10 Furnace Colossus")
	check(await fight_boss("furnace_colossus"), "Furnace Colossus defeated")
	check(Inv.count("core_key") >= 1, "Core Key dropped")
	check(Quests.completed.has("m10"), "quest m10 completed")

	print("-- m11 Pylons, Core Gate")
	tp_site("core_gate", 0, 10)
	await frames(40)
	var pylons: Array = w.sites.pylons
	check(pylons.size() == 3, "three pylons exist")
	pylons[1].interact(p)
	check(Game.stat("interact:pylon") == 0, "wrong pylon order resets progress")
	for i in 3:
		pylons[i].interact(p)
	check(Game.stat("interact:pylon") == 3, "pylons activated in order")
	var cg = null
	for c in w.get_node("Site_core_gate").get_children():
		if c.get("gate_id") == "core_gate":
			cg = c
	check(cg != null, "core gate exists")
	if cg:
		cg.interact(p)
	check(Game.flag("gate_core_gate"), "core gate opened with key and pylons")
	tp(140, 30)
	await frames(60)
	check(Game.regions_seen.has("core"), "core region entered")
	check(Quests.completed.has("m11"), "quest m11 completed")

	print("-- m12 Core Architect")
	check(await fight_boss("core_architect"), "Core Architect defeated (shield phases included)")
	check(Quests.completed.has("m12"), "quest m12 completed")
	check(Game.bosses_defeated.size() == 3, "all three bosses recorded")

	var missing := []
	for id in ["m01", "m02", "m03", "m04", "m05", "m06", "m07", "m08", "m09", "m10", "m11", "m12"]:
		if not Quests.completed.has(id):
			missing.append(id)
	check(missing.is_empty(), "all 12 main quests complete (missing: %s)" % str(missing))
	print("quest order completed: ", done_log)
	print("==== PLAYTHROUGH: %d passed, %d failed ====" % [ok, bad])
	get_tree().quit(1 if bad > 0 else 0)
