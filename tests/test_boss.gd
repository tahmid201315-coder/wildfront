extends Node
## Boss tests: every attack script of every boss executes, phases advance, defeat sequence completes and rewards apply.
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

func run(frames: int) -> void:
	for i in frames:
		stage.tick(1.0 / 60.0)

func _ready() -> void:
	await get_tree().process_frame
	stage = Stage.new()
	stage.headless_instant = true
	add_child(stage)
	await get_tree().process_frame
	for ri in Defs.REGION_ORDER.size():
		await test_boss(ri)
	print("\n== %d passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)

func start(ri: int) -> Boss:
	Game.new_progress()
	var region: String = Defs.REGION_ORDER[ri]
	for a in Game.ABILITY_NAMES:
		Game.unlock_ability(a)
	stage.load_room(LevelGen.build(region + "_boss"), "start")
	stage.player.use_script = true
	stage.player.inp = {}
	run(10)
	return stage.boss as Boss

func test_boss(ri: int) -> void:
	var region: String = Defs.REGION_ORDER[ri]
	var bid: String = Defs.REGIONS[region]["boss"]
	print("-- ", bid)
	var b := start(ri)
	check(bid + " spawned", b != null and b.state == "dormant")
	if b == null:
		return
	# wake it by walking into the arena
	stage.player.position.x = 12.0 * Level.T
	run(5)
	check(bid + " intro begins", b.state in ["intro", "fight"], b.state)
	run(120)
	check(bid + " fight starts", b.state == "fight", b.state)
	check(bid + " gate closed", stage.level.tile(2, 18) == Tiles.GATE)
	# every attack runs to completion without errors (player made safe)
	Game.god = true
	var cfg: Dictionary = BossData.DATA[bid]
	for name in cfg["attacks"].keys():
		b.stun_t = 0.0
		b.start_attack(name)
		var f := 0
		while not b.steps.is_empty() and f < 60 * 14:
			stage.tick(1.0 / 60.0)
			f += 1
		check("%s attack '%s' finishes" % [bid, name], b.steps.is_empty(), "frames %d" % f)
		stage.player.position = Vector2(14.0 * Level.T, b.floor_y)
		stage.player.vel = Vector2.ZERO
	Game.god = false
	# armour reduces damage outside vulnerability windows; vulnerable takes full
	b.vulnerable = false
	b.stun_t = 0.0
	var h0 := b.hp
	b.take_hit({"damage": 100.0, "from": Vector2.ZERO})
	var armored := h0 - b.hp
	b.vulnerable = true
	h0 = b.hp
	b.take_hit({"damage": 100.0, "from": Vector2.ZERO})
	check(bid + " armour reduces damage", armored < 100.0 and h0 - b.hp >= 99.0, "%f %f" % [armored, h0 - b.hp])
	# damage it through every phase
	var seen := {}
	var guard := 0
	while b.state != "dying" and b.state != "dead" and guard < 400:
		b.vulnerable = true
		b.take_hit({"damage": b.max_hp * 0.07, "from": Vector2.ZERO})
		seen[b.phase] = true
		Game.god = true
		run(100)
		Game.god = false
		guard += 1
	check(bid + " reached all %d phases" % cfg["phases"].size(), seen.size() >= cfg["phases"].size(), str(seen.keys()))
	run(60 * 5)
	check(bid + " defeat completes", b.state == "dead", b.state)
	check(bid + " marked defeated", Game.bosses.has(bid) and Game.flag("defeated_" + bid))
	check(bid + " fragment awarded", Game.fragments == 1, str(Game.fragments))
	check(bid + " gate opened", stage.level.tile(2, 18) != Tiles.GATE)
	var reward: String = LevelGen.BOSS_REWARDS[region]
	var altar := false
	for i in stage.interactables:
		if is_instance_valid(i) and i.kind == "altar":
			altar = true
	check(bid + " reward altar present", altar == (reward != ""), "reward=" + reward)
	check(bid + " player control restored", not stage.player.control_lock)
	# reloading the room does not respawn a defeated boss
	stage.load_room(LevelGen.build(region + "_boss"), "start")
	check(bid + " stays defeated", stage.boss == null)
