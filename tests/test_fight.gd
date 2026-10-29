extends Node
## A simple melee/magic bot fights every boss using Kael's real controls (invulnerable, so this measures whether the fight
## can be won by hitting the boss at all, how long it takes, and that phases and attacks really occur). It says nothing about
## how hard the fights are for a human; that is covered by the manual playthrough notes in docs/TESTING.md.
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

func _ready() -> void:
	await get_tree().process_frame
	stage = Stage.new()
	stage.headless_instant = true
	add_child(stage)
	await get_tree().process_frame
	for ri in Defs.REGION_ORDER.size():
		if OS.get_environment("ONLY") != "" and Defs.REGION_ORDER[ri] != OS.get_environment("ONLY"):
			continue
		for seed_v in ([int(OS.get_environment("SEED"))] if OS.get_environment("SEED") != "" else [11, 22, 33]):
			fight(ri, seed_v)
	print("\n== %d passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)

func fight(ri: int, seed_v: int) -> void:
	var region: String = Defs.REGION_ORDER[ri]
	var bid: String = Defs.REGIONS[region]["boss"]
	Game.new_progress()
	for a in Game.ABILITY_NAMES:
		Game.unlock_ability(a)
	Game.fragments = ri
	Game.level = 1 + ri * 2
	Game.skills = {"vitality": ri, "edge": mini(ri, 3), "crusher": mini(ri, 3)}
	stage.load_room(LevelGen.build(region + "_boss"), "start")
	var p := stage.player
	p.use_script = true
	for i in 10:
		stage.tick(1.0 / 60.0)
	var b: Boss = stage.boss
	stage.rng.seed = seed_v
	Game.god = true
	var t := 0.0
	var next_light := 0.0
	var max_phase := 0
	var attacks := {}
	var vuln_hits := 0
	var jumped_at := -1.0
	while t < 240.0 and b.state != "dying" and b.state != "dead":
		var inp := {}
		var dx := b.position.x - p.position.x
		var adx := absf(dx)
		if b.state == "dormant":
			inp["x"] = 1.0
		elif b.state == "fight" or b.state == "phase":
			if adx > 64.0:
				inp["x"] = signf(dx)
			else:
				inp["x"] = signf(dx) * 0.35   # keep facing the boss
			var want_air := b.flying and adx < 150.0
			if want_air and p.on_floor:
				inp["jump_pressed"] = true
				inp["jump_down"] = true
				jumped_at = t
			elif want_air:
				inp["jump_down"] = t - jumped_at < 0.5
			var facing_ok := (dx >= 0.0 and p.facing > 0) or (dx < 0.0 and p.facing < 0) or adx < 20.0
			if t >= next_light and facing_ok:
				if not p.on_floor or adx < 110.0:
					inp["light"] = true
					next_light = t + 0.22
				elif adx > 220.0 and Game.mp > 12.0:
					inp["magic"] = true
					next_light = t + 0.5
			if p.on_floor and adx < 110.0 and int(t * 2.0) % 7 == 3:
				inp["heavy"] = true
		p.inp = inp
		stage.tick(1.0 / 60.0)
		t += 1.0 / 60.0
		max_phase = maxi(max_phase, b.phase)
		if OS.get_environment("TRACE") != "" and int(t * 60.0) % 300 == 0:
			print("   t=%.0f adx=%.0f px=%.0f bx=%.0f state=%s atk=%s hp=%.0f vuln=%s pstate=%s onfloor=%s" % [t, adx, p.position.x, b.position.x, b.state, b.cur_attack, b.hp, b.vulnerable, p.state, p.on_floor])
		if b.cur_attack != "":
			attacks[b.cur_attack] = true
		Game.mp = minf(Game.mp + 0.3, Game.max_mp())
	check("%s (seed %d): bot defeats it with real attacks in %.0fs (phase %d reached, hp %.0f/%.0f)" % [bid, seed_v, t, max_phase + 1, b.hp, b.max_hp], b.state in ["dying", "dead"], "state=%s hp=%.0f t=%.0f" % [b.state, b.hp, t])
	check("%s: used %d different attacks during the fight" % [bid, attacks.size()], attacks.size() >= 3, str(attacks.keys()))
	check("%s: all phases reached" % bid, max_phase + 1 >= BossData.DATA[bid]["phases"].size() or b.state in ["dying", "dead"])
	Game.god = false
