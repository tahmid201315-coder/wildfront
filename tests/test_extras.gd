extends Node
## Tests for: auto-aim, battery saver, haptic mapping, achievements, scarves, equipment set bonus, elites, Echo bosses,
## New Game+, save export/import, daily trial seeding, tutorial flag, auto-pause.
var passed := 0
var failed := 0
var stage: Stage

func check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		passed += 1
		print("  ok   ", name)
	else:
		failed += 1
		print("  FAIL ", name, "  ", detail)

func run(n: int) -> void:
	for i in n:
		stage.tick(1.0 / 60.0)

func arena() -> LevelData:
	var rows: Array = []
	for y in 24:
		rows.append("#" + ".".repeat(78) + "#" if y < 20 else "#".repeat(80))
	var d := LevelData.new()
	d.id = "x_%d" % randi()
	d.region = "meadows"
	d.rows = PackedStringArray(rows)
	d.meta = {"spawns": {"start": [3, 19]}}
	d.finalize()
	return d

func fresh() -> Player:
	Game.new_progress()
	Game.god = false
	stage.load_room(arena(), "start")
	stage.player.use_script = true
	stage.player.inp = {}
	run(15)
	return stage.player

func _ready() -> void:
	await get_tree().process_frame
	Save.base_dir = "user://test_extras/"
	DirAccess.make_dir_recursive_absolute("user://test_extras/")
	stage = Stage.new()
	stage.headless_instant = true
	add_child(stage)
	await get_tree().process_frame
	test_aim_and_settings()
	test_achievements()
	test_set_and_scarf()
	test_elites()
	test_echo()
	test_ngp()
	test_save_share()
	await test_main_features()
	for s in 3:
		Save.delete_slot(s)
	print("\n== %d passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)

func test_aim_and_settings() -> void:
	print("-- auto-aim, battery saver, haptics")
	var p := fresh()
	var e := Spawner.spawn_entity(stage, {"t": "enemy", "k": "drone", "x": 12, "y": 14}) as Enemy
	e.hp = 9999.0
	p.position.x = 8.0 * 32.0
	p.facing = 1
	Game.settings["auto_aim"] = true
	p.inp = {"magic": true}
	stage.tick(1.0 / 60.0)
	p.inp = {}
	var bolt: Projectile = null
	for i in 20:
		stage.tick(1.0 / 60.0)
		for pr in stage.projectiles:
			if is_instance_valid(pr) and pr.friendly:
				bolt = pr
		if bolt != null:
			break
	check("auto-aim bolt flies upward toward a raised enemy", bolt != null and bolt.vel.y < -50.0, str(bolt.vel if bolt else "no bolt"))
	for pr in stage.projectiles:
		if is_instance_valid(pr):
			pr.alive = false
	Game.mp = Game.max_mp()
	Game.settings["auto_aim"] = false
	p.cast_done = false
	run(40)
	p.inp = {"magic": true}
	stage.tick(1.0 / 60.0)
	p.inp = {}
	bolt = null
	for i in 20:
		stage.tick(1.0 / 60.0)
		for pr in stage.projectiles:
			if is_instance_valid(pr) and pr.friendly and pr.alive:
				bolt = pr
		if bolt != null:
			break
	check("with auto-aim off the bolt flies straight", bolt != null and absf(bolt.vel.y) < 1.0, str(bolt.vel if bolt else "no bolt"))
	Game.settings["auto_aim"] = true
	Game.apply_setting("battery_saver", true)
	check("battery saver caps FPS at 30", Engine.max_fps == 30)
	Game.apply_setting("battery_saver", false)
	check("battery saver off uncaps FPS", Engine.max_fps == 0)
	Game.haptic(30)   # must not crash off-device
	check("haptic is safe off-device and every mapped sound exists", Sfx.HAPTICS.keys().all(func(k): return Sfx.RECIPES.has(k)))

func test_achievements() -> void:
	print("-- achievements")
	fresh()
	check("none unlocked at start", Achievements.count() == 0)
	Game.enemy_killed.emit("slime")
	check("first kill unlocks First Blood", Achievements.has("first_blood"))
	for i in 99:
		Game.enemy_killed.emit("slime")
	check("100 kills unlock Slayer", Achievements.has("slayer"))
	Game.bosses["meadow_colossus"] = true
	Game.progress_changed.emit()
	check("boss kill unlocks Guardian Slayer", Achievements.has("guardian"))
	for i in 20:
		Game.event.emit("chest")
	check("20 chests unlock Treasure Hunter", Achievements.has("treasure"))
	Game.event.emit("flawless")
	check("flawless boss unlocks its achievement", Achievements.has("flawless"))
	Game.level = 10
	Game.shards = 1000
	Game.progress_changed.emit()
	check("level and wealth achievements", Achievements.has("level10") and Achievements.has("rich"))
	var n := Achievements.count()
	Game.progress_changed.emit()
	check("achievements do not unlock twice", Achievements.count() == n)
	var d := Game.serialize()
	Game.new_progress()
	Game.deserialize(JSON.parse_string(JSON.stringify(d)))
	check("achievements persist through save/load", Achievements.has("slayer") and Achievements.stat("kills") == 100)
	Game.trial = true
	Achievements.unlock("daily")
	check("trial runs cannot unlock achievements directly", not Achievements.has("daily"))
	Game.trial = false

func test_set_and_scarf() -> void:
	print("-- set bonus and scarves")
	fresh()
	var dmg0 := Game.light_mult()
	var def0 := Game.equip_stat("defense")
	for id in ["windrunner_boots", "ember_charm", "guardian_pendant", "astral_lens"]:
		Game.give_equipment(id)
		Game.equip(id)
	check("four slots filled gives the set bonus", Game.full_set() and Game.light_mult() > dmg0 + 0.09)
	check("set bonus also adds defence", Game.equip_stat("defense") > def0 + 0.2)
	Game.unequip("lens")
	check("set bonus ends when a slot is empty", not Game.full_set())
	Game.settings["scarf"] = 1
	check("locked scarf falls back to crimson", Game.scarf_color() == Game.SCARVES[0]["color"] and not Game.scarf_unlocked(1))
	Game.set_flag("ach_slayer")
	check("unlocking the achievement unlocks the Gold scarf", Game.scarf_unlocked(1) and Game.scarf_color() == Game.SCARVES[1]["color"])
	Game.settings["scarf"] = 0

func test_elites() -> void:
	print("-- elites")
	var p := fresh()
	var a := Spawner.spawn_entity(stage, {"t": "enemy", "k": "guard", "x": 20, "y": 19}) as Enemy
	var b := Spawner.spawn_entity(stage, {"t": "enemy", "k": "guard", "x": 30, "y": 19, "elite": true}) as Enemy
	check("elite has more than twice the health", b.max_hp > a.max_hp * 2.0, "%f %f" % [b.max_hp, a.max_hp])
	check("elite hits harder and is bigger", b.contact_damage > a.contact_damage and b.size.x > a.size.x)
	var sh := Game.shards
	b.take_hit({"damage": 99999.0, "from": Vector2(0, 0)})
	run(60)
	check("elite kill is counted and pays out more", Achievements.has("elite") and Achievements.stat("elites") == 1)
	var elites := 0
	for id in LevelGen.all_room_ids():
		for e in World.get_room(id).meta.get("entities", []):
			if e.get("elite", false):
				elites += 1
	check("the campaign actually places elites (%d)" % elites, elites >= 10, str(elites))

func test_echo() -> void:
	print("-- Echo bosses")
	Game.new_progress()
	for a in Game.ABILITY_NAMES:
		Game.unlock_ability(a)
	stage.load_room(LevelGen.build("meadows_boss"), "start")
	var normal: Boss = stage.boss
	var hp_normal := normal.max_hp
	Game.new_progress()
	Game.bosses["meadow_colossus"] = true
	Game.set_flag("defeated_meadow_colossus")
	stage.load_room(LevelGen.build("meadows_boss"), "start")
	check("a defeated guardian stays gone before the ending", stage.boss == null)
	Game.completed = true
	stage.load_room(LevelGen.build("meadows_boss"), "start")
	var echo: Boss = stage.boss
	check("after the ending the guardian returns as an Echo", echo != null and echo.echo)
	check("Echo has 1.6x health (%.0f vs %.0f)" % [echo.max_hp, hp_normal], echo.max_hp > hp_normal * 1.55)
	stage.player.use_script = true
	stage.player.position.x = 12.0 * Level.T
	Game.god = true
	run(200)
	var frag := Game.fragments
	var shards := Game.shards
	echo.vulnerable = true
	echo.take_hit({"damage": 99999.0, "from": Vector2.ZERO})
	run(60 * 5)
	check("Echo defeat pays shards but gives no extra fragment", echo.state == "dead" and Game.fragments == frag and Game.shards > shards + 250, "%d %d" % [Game.fragments, Game.shards - shards])
	check("Echo defeat unlocks its achievement", Achievements.has("echo"))
	Game.god = false

func test_ngp() -> void:
	print("-- New Game+")
	fresh()
	Game.level = 12
	Game.skills = {"vitality": 3}
	Game.owned = {"windrunner_boots": true}
	Game.shards = 700
	Game.bosses = {"meadow_colossus": true}
	Game.fragments = 1
	Game.flags["puzzle_x"] = true
	Game.flags["ach_slayer"] = true
	Game.completed = true
	Game.quest_progress["stat_kills"] = 55
	var diff0: float = Game.difficulty()["enemy_hp"]
	Game.start_new_game_plus()
	check("NG+ increments the cycle", Game.ngp == 1)
	check("NG+ keeps level, skills, gear and money", Game.level == 12 and Game.skill("vitality") == 3 and Game.owned.has("windrunner_boots") and Game.shards == 700)
	check("NG+ resets the world", Game.bosses.is_empty() and Game.fragments == 0 and not Game.flag("puzzle_x") and not Game.completed and Game.checkpoint["level"] == "meadows_1")
	check("NG+ keeps achievements and counters", Game.flag("ach_slayer") and Achievements.stat("kills") == 55)
	check("NG+ makes enemies tougher (%.2f -> %.2f)" % [diff0, Game.difficulty()["enemy_hp"]], Game.difficulty()["enemy_hp"] > diff0 * 1.4 and Game.difficulty()["enemy_dmg"] > 1.2)
	var d := Game.serialize()
	Game.new_progress()
	Game.deserialize(JSON.parse_string(JSON.stringify(d)))
	check("NG+ cycle is saved", Game.ngp == 1)
	check("slot list shows NG+", true)
	Game.new_progress()
	check("a fresh game starts at cycle 0", Game.ngp == 0 and Game.difficulty()["enemy_hp"] == Defs.DIFFICULTY[int(Game.settings["difficulty"])]["enemy_hp"])

func test_save_share() -> void:
	print("-- save export / import")
	Game.new_progress()
	Game.shards = 4321
	Game.slot = 0
	Save.write_slot(0, Game.serialize())
	var code := Save.export_text(0)
	check("export gives a save code", code.begins_with("STARFALL1:") and code.length() > 40)
	var r := Save.import_text(1, code)
	check("import accepts its own code", r["ok"], str(r))
	var back := Save.load_slot(1)
	Game.new_progress()
	Game.deserialize(back["data"]["game"])
	check("imported save has the same progress", Game.shards == 4321)
	check("garbage is rejected", not Save.import_text(2, "hello")["ok"] and not Save.slot_exists(2))
	check("truncated code is rejected", not Save.import_text(2, code.substr(0, 30))["ok"] and not Save.slot_exists(2))
	var bad := "STARFALL1:" + Marshalls.utf8_to_base64("{\"save_version\": 1}")
	check("valid JSON with missing fields is rejected", not Save.import_text(2, bad)["ok"] and not Save.slot_exists(2))
	var future := "STARFALL1:" + Marshalls.utf8_to_base64(JSON.stringify({"save_version": 999, "game": {}}))
	check("future save versions are rejected", not Save.import_text(2, future)["ok"])
	check("an empty slot exports nothing", Save.export_text(2) == "")

func test_main_features() -> void:
	print("-- main flow: trial, tutorial, auto-pause")
	var a := Main_daily_seed()
	check("daily seed is stable for a date", a == Main_daily_seed())
	var days := {}
	for d in range(1, 15):
		days[load("res://scripts/main.gd").daily_seed({"year": 2026, "month": 10, "day": d})["region"]] = true
	check("daily trials rotate through the regions (%d different in 14 days)" % days.size(), days.size() >= 6)
	var m: Node = load("res://scenes/main.tscn").instantiate()
	add_child(m)
	await get_tree().physics_frame
	m._on_daily()
	await get_tree().physics_frame
	check("daily trial loads a boss arena and disables saving", Game.trial and m.stage.room_id.ends_with("_boss") and not m.stage.autosave())
	check("trial player has every ability", Game.has_ability("dash") and Game.has_ability("stasis"))
	m.auto_pause()
	check("losing focus pauses the game", Game.state == Game.State.PAUSE and m.menus.current == "pause")
	m.menus.close_all()
	Game.trial = false
	Game.set_state(Game.State.TITLE)
	check("tutorial flag is a normal saved flag", not Game.flag("tut_done"))
	Game.set_flag("tut_done")
	var d := Game.serialize()
	check("tutorial completion is saved", d["flags"].has("tut_done"))
	m.queue_free()

func Main_daily_seed() -> Dictionary:
	return load("res://scripts/main.gd").daily_seed({"year": 2026, "month": 10, "day": 29})
