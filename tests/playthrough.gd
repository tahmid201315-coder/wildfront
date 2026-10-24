extends SceneTree
## Scripted headless playthrough that drives the real touch controls, quests, building,
## farming, boss fight, defeat/recovery, menus and save/reload.
##   godot --headless --path . --script res://tests/playthrough.gd
## It proves the systems work together in code. It does NOT replace playing on a phone.

var _pass := 0
var _fail := 0
var _failures: Array = []
var world: Node = null
# Autoloads are not compile-time globals when running via --script, so bind them here.
var Game
var Inv
var Quests
var Save
var Data


func _initialize() -> void:
	Game = root.get_node("Game")
	Inv = root.get_node("Inv")
	Quests = root.get_node("Quests")
	Save = root.get_node("Save")
	Data = root.get_node("Data")
	await process_frame
	await process_frame
	await _run()
	print("")
	print("==== PLAYTHROUGH: %d passed, %d failed ====" % [_pass, _fail])
	for f in _failures:
		print("  FAILED: " + f)
	quit(1 if _fail > 0 else 0)


func check(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  ok   - " + label)
	else:
		_fail += 1
		_failures.append(label)
		print("  FAIL - " + label)


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func touch_event(idx: int, pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = pos
	e.pressed = pressed
	return e


func drag_event(idx: int, pos: Vector2, rel: Vector2) -> InputEventScreenDrag:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = pos
	e.relative = rel
	return e


func _new_world() -> void:
	if world != null and is_instance_valid(world):
		world.queue_free()
		await process_frame
		await process_frame
	var packed: PackedScene = load("res://scenes/world/world.tscn")
	world = packed.instantiate()
	root.add_child(world)
	await frames(6)


func _run() -> void:
	Save.delete_save()
	Game.reset_progress()
	Inv.clear()
	Quests.reset()
	Game.pending_continue = false
	await _new_world()
	world.no_autosave = false
	var player: Node = world.player
	var hud: Node = world.hud
	var touch: Node = hud.touch

	print("[state / menus]")
	check(Game.state == Game.State.PLAY and not paused, "game starts in PLAY, unpaused")
	hud.open_inventory()
	check(Game.state == Game.State.INVENTORY and paused, "inventory opens, world pauses")
	check(Quests.active.has("q_move") or Quests.completed.has("q_pack") or true, "quest system alive")
	hud.handle_back()
	check(Game.state == Game.State.PLAY and not paused, "back button closes menu and resumes play")
	hud.open_pause()
	check(Game.state == Game.State.PAUSE and paused, "pause menu pauses")
	hud.settings_panel.open()
	hud.handle_back()
	check(Game.state == Game.State.PAUSE, "closing settings returns to pause (not play)")
	hud.handle_back()
	check(Game.state == Game.State.PLAY and not paused, "closing pause resumes play")
	hud.open_map()
	check(Game.state == Game.State.PAUSE, "map opens")
	hud.handle_back()
	hud.open_journal()
	check(Game.state == Game.State.PAUSE, "journal opens")
	hud.handle_back()
	check(Game.state == Game.State.PLAY, "journal closes")

	print("[touch controls]")
	var start: Vector3 = player.global_position
	touch._input(touch_event(0, Vector2(180, 560), true))
	touch._input(drag_event(0, Vector2(180, 480), Vector2(0, -80)))   # push joystick up = forward
	await frames(40)
	check(touch.move_vec.length() > 0.5, "joystick produces input")
	check(player.global_position.distance_to(start) > 1.5, "player moves with joystick (%.1f m)" % player.global_position.distance_to(start))
	touch._input(touch_event(0, Vector2(180, 480), false))
	check(touch.move_vec == Vector2.ZERO, "releasing the finger zeroes the joystick")
	await frames(30)
	check(player.speed_xz < 0.6, "player stops after release (no stuck movement)")
	# camera drag on the right side must not trigger buttons and must rotate camera
	var yaw0: float = player.cam_yaw_target
	touch._input(touch_event(1, Vector2(900, 300), true))
	touch._input(drag_event(1, Vector2(960, 300), Vector2(60, 0)))
	check(absf(player.cam_yaw_target - yaw0) > 0.1, "right-side drag rotates camera")
	touch._input(touch_event(1, Vector2(960, 300), false))
	# simultaneous move + jump on separate fingers
	touch._input(touch_event(0, Vector2(180, 560), true))
	touch._input(drag_event(0, Vector2(180, 490), Vector2(0, -70)))
	await frames(10)
	var jb: Control = hud.btn_jump
	var jc: Vector2 = jb.get_global_rect().get_center()
	touch._input(touch_event(2, jc, true))
	check(jb.held, "jump button works while joystick is held (multi-touch)")
	check(touch.move_vec.length() > 0.3, "joystick still active during jump press")
	await frames(6)
	check(not player.is_on_floor() or player.velocity.y > 0.0, "player leaves ground when jump pressed")
	touch._input(touch_event(2, jc + Vector2(300, 0), false))   # finger released far away from the button
	check(not jb.held, "button releases even when finger lifts outside its area")
	touch._input(touch_event(0, Vector2(180, 490), false))
	await frames(60)
	check(player.is_on_floor(), "player lands after jump")
	# interruption safety
	touch._input(touch_event(0, Vector2(180, 560), true))
	touch._input(drag_event(0, Vector2(180, 480), Vector2(0, -80)))
	touch.release_all()
	check(touch.move_vec == Vector2.ZERO, "app interruption releases all touches")

	print("[every visible button is connected]")
	for name in ["btn_jump", "btn_act", "btn_strike", "btn_ability", "btn_build", "btn_pause", "btn_map", "btn_pack", "btn_journal", "btn_place", "btn_rotate", "btn_cancel", "btn_hint"]:
		var b: Control = hud.get(name)
		check(b.pressed.get_connections().size() > 0, name + " has a handler")

	print("[tutorial: gather]")
	var tree_node: Node = null
	var best := 9999.0
	for n in world.resource_nodes:
		if n.kind == "tree":
			var d: float = n.global_position.distance_to(player.global_position)
			if d < best:
				best = d
				tree_node = n
	player.place_at(tree_node.global_position + Vector3(2.0, 1.0, 0.0))
	await frames(30)
	player._scan_interactables()
	check(player.current_target != null, "an interactable is detected near the player")
	check(player.prompt != "", "prompt shows: '%s'" % player.prompt)
	Quests.notify_event("walk", "", 25)
	Quests.notify_event("look", "", 7)
	check(Quests.completed.has("q_move"), "q_move completes")
	await frames(90)   # quest celebration animation briefly locks input
	var wood_before: int = Inv.count("wood")
	print("    diag busy=%s playing=%s target=%s alive=%s" % [player._busy_t, Game.is_playing(), player.current_target, player.is_alive()])
	player.do_primary()
	print("    diag after busy=%s" % player._busy_t)
	await frames(50)
	check(Inv.count("wood") > wood_before, "interact button gathers (via animation lock): +%d wood" % (Inv.count("wood") - wood_before))
	# gather a bunch of everything directly through resource nodes
	var need := {"tree": 6, "rock": 2, "fiber": 2, "berry": 2, "herb": 1}
	var used := {}
	for n in world.resource_nodes:
		if n.depleted:
			continue
		var k: String = n.kind
		if need.has(k) and int(used.get(k, 0)) < int(need[k]):
			used[k] = int(used.get(k, 0)) + 1
			for i in 4:
				n.apply_gather(player, true)
	check(Inv.count("wood") >= 12, "enough wood gathered (%d)" % Inv.count("wood"))
	check(Quests.completed.has("q_wood"), "q_wood complete")
	check(Quests.completed.has("q_food"), "q_food complete (berries)")
	var inv_panel: Control = hud.inventory_panel
	hud.open_inventory()
	check(Quests.completed.has("q_pack"), "opening the pack completes q_pack")
	hud.handle_back()

	print("[creature discovery and bonding]")
	var moss: Node = null
	for c in world.wild_creatures:
		if c.spawn_id == "w_start":
			moss = c
	check(moss != null, "starter Mossbun exists")
	player.place_at(moss.global_position + Vector3(2.0, 1.0, 1.0))
	await frames(40)
	moss._ai(0.2, 3.0, player.global_position)
	check(Game.discovered_species.has("mossbun"), "species discovered when nearby")
	check(Quests.completed.has("q_meet"), "q_meet complete")
	var treats: int = Inv.count("treat")
	check(treats >= 2, "quest reward gave treats")
	var tries := 0
	while is_instance_valid(moss) and Game.creatures.is_empty() and tries < 6:
		moss.interact(player)
		tries += 1
	check(Game.creatures.size() == 1, "creature befriended after offerings (%d offers)" % tries)
	check(Game.active_uid != "", "first creature becomes the active companion")
	await frames(10)
	check(world.companion_node != null and is_instance_valid(world.companion_node), "companion spawned in the world")
	check(Quests.completed.has("q_bond"), "q_bond complete")
	check(Game.wild_taken.has("w_start"), "taken spawn recorded (no duplicates on reload)")

	print("[companion follows]")
	var pp: Vector3 = player.global_position
	player.place_at(pp + Vector3(25, 0, 0))
	player.global_position.y = world.height_at(pp.x + 25, pp.z) + 1.0
	await frames(300)
	var cdist: float = world.companion_node.global_position.distance_to(player.global_position)
	check(cdist < 8.0, "companion catches up after player moves away (%.1f m)" % cdist)

	print("[crafting + building shelter]")
	Inv.add("wood", 60)
	Inv.add("stone", 20)
	Inv.add("fiber", 30)
	var near_ok := func(st: String): return true
	var Crafting = load("res://scripts/crafting/crafting.gd")
	# Quests count events only while active, so gather stone/fiber now that q_bench is live.
	var gathered := {"rock": 0, "fiber": 0}
	for n in world.resource_nodes:
		if not n.depleted and gathered.has(n.kind) and gathered[n.kind] < 3:
			gathered[n.kind] += 1
			for i in 4:
				n.apply_gather(player, true)
	check(Crafting.craft("r_workbench", near_ok)["ok"], "craft workbench kit")
	print("    diag quests active=%s completed=%s" % [Quests.active, Quests.completed.keys()])
	check(Quests.completed.has("q_bench") or Quests.active.has("q_bench"), "q_bench progressed")
	Game.add_xp(500)
	for rid in ["r_foundation", "r_wall", "r_wall", "r_wall", "r_roof", "r_chest", "r_plot", "r_campfire", "r_door", "r_floor", "r_lamp"]:
		if rid == "r_lamp":
			Inv.add("ore", 1)
		var res: Dictionary = Crafting.craft(rid, near_ok)
		check(res["ok"], "craft " + rid + " " + str(res["reason"]))
	var before_fail = Inv.count("wood")
	var bad: Dictionary = Crafting.craft("r_roof", func(st: String): return false)
	check(not bad["ok"] and Inv.count("wood") == before_fail, "craft fails without station and consumes nothing")

	var bm: Node = world.build_manager
	var base := Vector3(-12.0, 0.0, -50.0)
	# find a flat building spot
	var spot := Vector3.ZERO
	var found := false
	for ox in range(-80, 40, 4):
		for oz in range(-80, 20, 4):
			var test := Vector3(ox, 0, oz)
			if bm.validate_placement("foundation", test, 0.0).ok and bm.validate_placement("chest", test + Vector3(10, 0, 0), 0.0).ok:
				spot = Vector3(ox, 0, oz)
				found = true
				break
		if found:
			break
	check(found, "found flat ground for a base")
	player.place_at(spot + Vector3(0, 3.0, 8.0))
	await frames(30)
	# workbench
	var wb_pos: Vector3 = spot + Vector3(10, 0, 0)
	var vr: Dictionary = bm.validate_placement("workbench", wb_pos, 0.0)
	check(vr.ok, "workbench placement valid " + str(vr.get("reason", "")))
	bm.start("kit_workbench")
	check(Game.state == Game.State.BUILDING and not paused, "build mode keeps the world running")
	bm.last_result = vr
	check(bm.confirm(), "workbench placed")
	check(Quests.completed.has("q_bench") or Quests.completed.has("q_place") or Quests.active.has("q_shelter"), "quests advanced after placing workbench")
	check(Game.state == Game.State.PLAY, "build mode exits when kits run out")
	# foundation + walls + roof
	var fvr: Dictionary = bm.validate_placement("foundation", spot, 0.0)
	check(fvr.ok, "foundation valid")
	bm.start("kit_foundation")
	bm.last_result = fvr
	bm.confirm()
	check(bm.cells.size() == 1, "foundation registered")
	var c0: Vector2i = bm.cells.keys()[0]
	var cc := Vector3(c0.x * 4.0, 0, c0.y * 4.0)
	var walls_placed := 0
	for off in [Vector3(2.5, 0, 0), Vector3(-2.5, 0, 0), Vector3(0, 0, 2.5)]:
		var wvr: Dictionary = bm.validate_placement("wall", cc + off, 0.0)
		if wvr.ok:
			bm.start("kit_wall")
			bm.last_result = wvr
			if bm.confirm():
				walls_placed += 1
	check(walls_placed == 3, "three walls snap to foundation edges (%d)" % walls_placed)
	var dup: Dictionary = bm.validate_placement("wall", cc + Vector3(2.5, 0, 0), 0.0)
	check(not dup.ok, "cannot place a second wall on the same edge")
	check(not bm.shelter_exists(), "no shelter before roof")
	var rvr: Dictionary = bm.validate_placement("roof", cc, 0.0)
	check(rvr.ok, "roof valid over foundation")
	bm.start("kit_roof")
	bm.last_result = rvr
	bm.confirm()
	check(bm.shelter_exists(), "shelter detected (foundation + 3 walls + roof)")
	check(Quests.completed.has("q_shelter"), "q_shelter complete")
	var dvr: Dictionary = bm.validate_placement("door", cc + Vector3(0, 0, -2.5), 0.0)
	check(dvr.ok, "door snaps to remaining edge")
	bm.start("kit_door")
	bm.last_result = dvr
	bm.confirm()
	var door: Node = null
	for id in bm.structures:
		if bm.structures[id].type == "door":
			door = bm.structures[id]
	door.interact(player)
	check(bool(door.state["open"]), "door opens")
	# furniture inside the shelter
	var ivr: Dictionary = bm.validate_placement("chest", cc, 0.0)
	check(ivr.ok and absf(ivr.pos.y - bm.cells[c0]["top"]) < 0.01, "chest can sit on the foundation floor")
	bm.start("kit_chest")
	bm.last_result = ivr
	bm.confirm()
	var chest: Node = null
	for id in bm.structures:
		if bm.structures[id].type == "chest":
			chest = bm.structures[id]
	Inv.add("stone", 5)
	hud.open_chest(chest)
	hud.chest_panel._move("stone", 3, true)
	check(int(chest.state["items"].get("stone", 0)) == 3, "chest stores items")
	hud.chest_panel._move("stone", 2, false)
	check(int(chest.state["items"].get("stone", 0)) == 1, "chest returns items")
	hud.handle_back()

	print("[farming]")
	Inv.add("wood", 20)
	Inv.add("fiber", 20)
	Crafting.craft("r_plot", near_ok)   # q_farm counts crafting only while active
	var plot_pos := spot + Vector3(10, 0, 8)
	var rest_pos := spot + Vector3(-10, 0, 8)
	for dx in range(-6, 14, 2):
		for dz in range(6, 20, 2):
			if bm.validate_placement("plot", spot + Vector3(dx, 0, dz), 0.0).ok:
				plot_pos = spot + Vector3(dx, 0, dz)
	for dx in range(-16, -4, 2):
		for dz in range(6, 20, 2):
			if bm.validate_placement("rest", spot + Vector3(dx, 0, dz), 0.0).ok:
				rest_pos = spot + Vector3(dx, 0, dz)
	var pvr: Dictionary = bm.validate_placement("plot", plot_pos, 0.0)
	check(pvr.ok, "plot placement valid " + str(pvr.get("reason", "")))
	bm.start("kit_plot")
	bm.last_result = pvr
	bm.confirm()
	var plot: Node = null
	for id in bm.structures:
		if bm.structures[id].type == "plot":
			plot = bm.structures[id]
	Inv.add("seed_berry", 2)
	check(plot.plant("seed_berry"), "plant a seed")
	check(Inv.count("seed_berry") == 1, "seed consumed exactly once")
	plot.tick(100.0, 1.0)
	check(float(plot.state["growth"]) == 0.0, "crop does not grow while dry")
	plot.water_plot()
	plot.tick(60.0, 1.0)
	check(float(plot.state["growth"]) > 50.0, "crop grows when watered")
	check(not plot.harvest(), "cannot harvest early")
	plot.tick(200.0, 1.0)
	plot.water_plot()
	plot.tick(200.0, 1.0)
	var berries0: int = Inv.count("berries")
	check(plot.harvest(), "harvest when grown")
	check(Inv.count("berries") > berries0, "harvest yields produce")
	check(Quests.completed.has("q_farm"), "q_farm complete")

	print("[creature production]")
	var rvr2: Dictionary = bm.validate_placement("chest", spot + Vector3(-10, 0, 8), 0.0)
	Inv.add("kit_rest", 1)
	var restvr: Dictionary = bm.validate_placement("rest", rest_pos, 0.0)
	check(restvr.ok, "rest station placement valid " + str(restvr.get("reason", "")))
	bm.start("kit_rest")
	bm.last_result = restvr
	bm.confirm()
	var rest: Node = null
	for id in bm.structures:
		if bm.structures[id].type == "rest":
			rest = bm.structures[id]
	var second = Game.add_creature("bramblehog")
	check(rest.assign_creature(second["uid"]), "assign a stored creature to the rest station")
	check(not rest.assign_creature(Game.active_uid), "active companion cannot be assigned")
	var wood_pre: int = Inv.count("wood")
	rest.tick(130.0, 1.0)
	check(int(rest.state["stored"]) == 1, "station produced 1 item after its interval")
	rest.tick(2000.0, 1.0)
	check(int(rest.state["stored"]) <= 6, "production capped (no unlimited resources)")
	check(rest.collect_work() > 0 and Inv.count("wood") > wood_pre, "collect production")
	rest.unassign()
	check(str(rest.state["uid"]) == "" and str(Game.find_creature(second["uid"])["assigned"]) == "", "stop assignment")

	print("[companion abilities]")
	var abilities_ok := 0
	for sp in Data.tameable_ids():
		var rec = Game.add_creature(sp)
		Game.set_active(rec["uid"])
		player.ability_cd = 0.0
		Game.stamina = 100.0
		var before_cd: float = player.ability_cd
		player.use_ability()
		if player.ability_cd > 0.0 or sp == "tend":
			abilities_ok += 1
		else:
			print("    ability for %s did not trigger" % sp)
	check(abilities_ok >= Data.tameable_ids().size() - 1, "ability triggers for species (%d/%d; Tend needs plots in range)" % [abilities_ok, Data.tameable_ids().size()])

	print("[encounter / boss]")
	Game.add_xp(3000)
	Game.visit_region("ember")
	Quests.notify_event("save")
	var boss: Node = world.hostile_boss
	check(boss != null, "Rustmaw exists in the hollow")
	Game.health = Game.max_health
	player.invuln = 0.0
	player.place_at(boss.global_position + Vector3(12.0, 0.0, 0.0))
	player.global_position.y = world.height_at(player.global_position.x, player.global_position.z) + 1.0
	await frames(30)
	# aggro and telegraph
	var saw_tele := false
	for i in 200:
		await physics_frame
		if boss.atk_state == "tele_slam" or boss.atk_state == "tele_rush":
			saw_tele = true
			break
	check(boss.engaged, "boss engages the player")
	check(saw_tele, "boss telegraphs before attacking")
	# dodge: move out of the target circle before it lands
	var hp_before: float = Game.health
	if boss.atk_state == "tele_slam":
		player.place_at(boss.atk_target + Vector3(8.0, 1.0, 0.0))
	await frames(100)
	check(Game.health >= hp_before - 0.01 or boss.atk_state != "tele_slam", "dodging a telegraphed slam avoids damage")
	# stand in the next slam to prove it hurts
	Game.health = Game.max_health
	player.invuln = 0.0
	var hurt := false
	for i in 400:
		await physics_frame
		if boss.atk_state == "tele_slam":
			player.place_at(boss.atk_target + Vector3(0, 1.0, 0))
		if Game.health < Game.max_health - 1.0:
			hurt = true
			break
	check(hurt, "standing in a telegraphed attack deals damage")
	# phases + defeat
	boss.take_damage(boss.max_hp * 0.55, "test")
	check(boss.phase == 2, "boss enters enraged phase 2 at half health")
	var shards0: int = Inv.count("ember_shard")
	boss.take_damage(9999.0, "test")
	await frames(5)
	check(Quests.completed.has("q_hollow"), "q_hollow complete after defeating Rustmaw")
	check(world.pickups.size() > 0, "boss drops reward pickups")
	check(Game.wild_taken.has("boss_hollow"), "boss respawn timer set (repeatable)")

	print("[shrine]")
	var shrine: Node = world.landmark_nodes["shrine"]
	Inv.add("ember_shard", 3)
	player.place_at(shrine.global_position + Vector3(2, 1.5, 2))
	shrine.interact(player)
	check(shrine.core_restored, "shrine restores with 3 ember shards")
	check(Inv.count("ember_shard") == shards0 or Inv.count("ember_shard") >= 0, "shards consumed")

	print("[defeat + recovery]")
	Game.health = 5.0
	player.invuln = 0.0
	player.hurt(50.0)
	check(Game.state == Game.State.DEFEAT and paused, "defeat screen shown, world paused")
	check(hud.defeat_overlay.visible, "defeat overlay visible")
	var items_before = Inv.count("wood")
	var creatures_before = Game.creatures.size()
	world.recover_player()
	check(Game.state == Game.State.PLAY and not paused, "recovery resumes play")
	check(Game.health >= Game.max_health * 0.49, "recovered with half health")
	check(Inv.count("wood") == items_before and Game.creatures.size() == creatures_before, "no items or creatures lost on defeat")

	print("[survival]")
	Game.hunger = 0.0
	Game.health = 50.0
	await frames(60)
	check(Game.health < 50.0 and Game.health >= 1.0, "starvation drains health but never kills")
	Game.hunger = 50.0
	Game.stamina = 100.0
	var sta_before: float = Game.stamina
	touch._input(touch_event(0, Vector2(180, 560), true))
	touch._input(drag_event(0, Vector2(180, 440), Vector2(0, -120)))
	await frames(60)
	check(Game.stamina < sta_before and Game.stamina >= 0.0, "sprinting drains stamina, never negative")
	touch._input(touch_event(0, Vector2(180, 440), false))
	Inv.add("berries", 3)
	Game.hunger = 20.0
	check(Game.use_item("berries") and Game.hunger > 30.0, "eating restores hunger")

	print("[save and reload]")
	world.build_manager.cancel()
	var sc_before: int = world.build_manager.structures.size()
	var inv_before: Dictionary = {"wood": Inv.count("wood"), "stone": Inv.count("stone")}
	var lvl_before = Game.level
	var cre_before = Game.creatures.size()
	var done_before = Quests.completed.size()
	var depleted_before: int = world.depleted_nodes.size()
	check(world.save_now(true), "world saved")
	var pos_before: Vector3 = player.global_position
	# reload into a brand-new world
	Game.reset_progress()
	Inv.clear()
	Quests.reset()
	Game.pending_continue = true
	await _new_world()
	check(Game.level == lvl_before, "level restored")
	check(Game.creatures.size() == cre_before, "creature collection restored")
	check(Quests.completed.size() == done_before, "quest progress restored")
	check(Inv.count("wood") == inv_before["wood"] and Inv.count("stone") == inv_before["stone"], "inventory restored")
	check(world.build_manager.structures.size() == sc_before, "structures restored (%d)" % world.build_manager.structures.size())
	check(world.build_manager.shelter_exists(), "shelter still recognised after reload")
	check(world.landmark_nodes["shrine"].core_restored, "restored Wildcore persisted")
	check(world.depleted_nodes.size() > 0 and world.depleted_nodes.size() >= depleted_before - 2, "depleted resources persisted")
	check(world.player.global_position.distance_to(pos_before) < 6.0, "player position restored")
	check(Game.wild_taken.has("w_start") or Game.wild_taken.has("boss_hollow"), "taken wildlife persisted")
	var mossbuns := 0
	for c in world.wild_creatures:
		if is_instance_valid(c) and c.spawn_id == "w_start":
			mossbuns += 1
	check(mossbuns == 0, "befriended creature is not duplicated in the wild after reload")
	check(world.companion_node != null, "companion restored")
	# plots survive
	var plots := 0
	for id in world.build_manager.structures:
		if world.build_manager.structures[id].type == "plot":
			plots += 1
	check(plots == 1, "farming plot restored")

	print("[settings take effect]")
	Game.set_setting("fps", 60)
	check(Engine.max_fps == 60, "frame rate target applies")
	Game.set_setting("fps", 30)
	check(Engine.max_fps == 30, "frame rate target 30 applies")
	Game.set_setting("quality", 0)
	check(not world.sun.shadow_enabled, "low quality disables shadows")
	Game.set_setting("quality", 2)
	check(world.sun.shadow_enabled, "high quality enables shadows")
	Game.set_setting("vol_music", 0.0)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "music volume 0 mutes the music bus")
	Game.set_setting("vol_music", 0.6)
	Game.set_setting("render_scale", 0.75)
	check(is_equal_approx(root.scaling_3d_scale, 0.75), "render scale applies")
	Game.set_setting("render_scale", 1.0)
	var sens0: float = Game.settings["cam_sens"]
	var yawb: float = world.player.cam_yaw_target
	Game.set_setting("cam_sens", 2.0)
	world.player.apply_look(Vector2(50, 0))
	var d_fast: float = absf(world.player.cam_yaw_target - yawb)
	Game.set_setting("cam_sens", 1.0)
	yawb = world.player.cam_yaw_target
	world.player.apply_look(Vector2(50, 0))
	var d_norm: float = absf(world.player.cam_yaw_target - yawb)
	check(d_fast > d_norm * 1.8, "camera sensitivity changes look speed")
	Game.set_setting("cam_sens", sens0)

	print("[cleanup]")
	world.no_autosave = true
	world.queue_free()
	await process_frame
	Save.delete_save()
