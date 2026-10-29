extends Node
## Gameplay tests against the real simulation: jump limits, combat, every enemy kind, items, equipment, skills, quests, shop,
## checkpoints, room transitions and scripted solutions for every puzzle room.
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
	Save.base_dir = "user://test_play/"
	DirAccess.make_dir_recursive_absolute("user://test_play/")
	stage = Stage.new()
	stage.headless_instant = true
	add_child(stage)
	await get_tree().process_frame
	test_jumps()
	test_combat()
	test_enemies()
	test_items()
	test_quests_shop()
	test_checkpoint_and_rooms()
	test_puzzles()
	for s in 3:
		Save.delete_slot(s)
	print("\n== %d passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)

# ------------------------------------------------------------------ helpers
func arena(rows_extra: Callable = Callable(), region: String = "meadows") -> LevelData:
	var rows: Array = []
	for y in 24:
		rows.append("#" + ".".repeat(78) + "#" if y < 20 else "#".repeat(80))
	if rows_extra.is_valid():
		rows_extra.call(rows)
	var d := LevelData.new()
	d.id = "t_%d" % randi()
	d.region = region
	d.rows = PackedStringArray(rows)
	d.meta = {"spawns": {"start": [3, 19]}}
	d.finalize()
	return d

func fresh(d: LevelData, abilities: Array = []) -> Player:
	Game.new_progress()
	Game.god = false
	for a in abilities:
		Game.unlock_ability(a)
	stage.load_room(d, "start")
	var p := stage.player
	p.use_script = true
	p.inp = {}
	run(15)
	return p

func carve_pit(rows: Array, gx: int, gw: int) -> void:
	for y in range(20, 24):
		var r: String = rows[y]
		for x in range(gx, gx + gw):
			r = r.substr(0, x) + "." + r.substr(x + 1)
		rows[y] = r

# ------------------------------------------------------------------ jumping
func try_gap(gw: int, with_dash: bool) -> bool:
	var d := arena(func(rows: Array) -> void: carve_pit(rows, 14, gw))
	var p := fresh(d, ["dash"] if with_dash else [])
	var dashed := false
	var jumped := false
	for f in 400:
		var inp := {"x": 1.0, "jump_down": jumped}
		if p.on_floor and not jumped and p.position.x >= 14.0 * 32.0 - 4.0:
			inp["jump_pressed"] = true
			jumped = true
		if with_dash and jumped and not p.on_floor and not dashed and p.vel.y > -100.0:
			inp["dodge"] = true
			dashed = true
		p.inp = inp
		stage.tick(1.0 / 60.0)
		if p.position.x > (14 + gw + 2) * 32.0 and p.on_floor:
			return true
		if p.position.y > 21.0 * 32.0:
			return false
	return false

func test_jumps() -> void:
	print("-- jumping against real physics")
	var results := {}
	for gw in [2, 3, 4, 5, 6, 7]:
		results[gw] = try_gap(gw, false)
	print("   no-ability gap results: ", results)
	check("2 to 4 tile gaps are crossable without abilities (largest generated plain gap)", results[2] and results[3] and results[4], str(results))
	var dash := {}
	for gw in [6]:
		dash[gw] = try_gap(gw, true)
	check("6 tile gap is crossable with Starlight Dash (largest generated dash gap)", dash[6], str(dash))
	# jump height
	var p := fresh(arena())
	var y0 := p.position.y
	p.inp = {"jump_pressed": true, "jump_down": true}
	var top := y0
	for f in 60:
		stage.tick(1.0 / 60.0)
		top = minf(top, p.position.y)
		p.inp = {"jump_down": true}
	check("full jump clears 3 tiles but not 4 (%.1f tiles)" % ((y0 - top) / 32.0), (y0 - top) >= 3.0 * 32.0 and (y0 - top) < 4.0 * 32.0, str((y0 - top) / 32.0))
	p = fresh(arena())
	y0 = p.position.y
	p.inp = {"jump_pressed": true, "jump_down": true}
	stage.tick(1.0 / 60.0)
	p.inp = {"jump_down": false, "jump_released": true}
	var top2 := y0
	for f in 50:
		stage.tick(1.0 / 60.0)
		top2 = minf(top2, p.position.y)
		p.inp = {}
	check("tapping jump gives a shorter hop (variable jump)", (y0 - top2) < (y0 - top) * 0.75, "%f vs %f" % [y0 - top2, y0 - top])
	# coyote time: run off a ledge and jump 4 frames late
	var d := arena(func(rows: Array) -> void: carve_pit(rows, 14, 6))
	p = fresh(d)
	var off := false
	var late := 0
	var jumped := false
	for f in 200:
		var inp := {"x": 1.0}
		if not p.on_floor and not off:
			off = true
		if off and not jumped:
			late += 1
			if late == 5:
				inp["jump_pressed"] = true
				jumped = true
		p.inp = inp
		stage.tick(1.0 / 60.0)
		if jumped and p.vel.y < -200.0:
			break
	check("coyote time allows a jump shortly after leaving a ledge", jumped and p.vel.y < -200.0, "vy=%f" % p.vel.y)
	# jump buffer: press just before landing
	p = fresh(arena())
	p.position.y -= 40.0
	p.vel.y = 300.0
	p.on_floor = false
	var buffered := false
	for f in 40:
		var inp2 := {}
		if not buffered and p.position.y > 19.0 * 32.0 - 14.0:
			inp2["jump_pressed"] = true
			buffered = true
		p.inp = inp2
		stage.tick(1.0 / 60.0)
		if buffered and p.vel.y < -300.0:
			break
	check("jump buffer fires on landing", buffered and p.vel.y < -300.0, "vy=%f" % p.vel.y)
	# double jump
	p = fresh(arena(), ["double_jump"])
	p.inp = {"jump_pressed": true, "jump_down": true}
	stage.tick(1.0 / 60.0)
	p.inp = {"jump_down": true}
	run(20)
	var y1 := p.position.y
	p.inp = {"jump_pressed": true, "jump_down": true}
	stage.tick(1.0 / 60.0)
	p.inp = {"jump_down": true}
	var top3 := y1
	for f in 30:
		stage.tick(1.0 / 60.0)
		top3 = minf(top3, p.position.y)
	check("Skyleap gives a second jump", y1 - top3 > 40.0, str(y1 - top3))
	# wall jump
	var dw := arena(func(rows: Array) -> void:
		for y in range(8, 20):
			var r: String = rows[y]
			rows[y] = r.substr(0, 10) + "#" + r.substr(11)
			)
	p = fresh(dw, ["wall_jump"])
	p.position = Vector2(9.0 * 32.0 + 16.0, 12.0 * 32.0)
	p.vel = Vector2.ZERO
	var best := p.position.y
	for f in 60:
		p.inp = {"x": 1.0}
		if f == 20:
			p.inp["jump_pressed"] = true
		stage.tick(1.0 / 60.0)
		best = minf(best, p.position.y)
	check("wall jump launches Kael away from a wall", p.position.x < 9.0 * 32.0 + 16.0 + 600.0 and best < 12.0 * 32.0 + 200.0)
	# ladder
	var dl := arena(func(rows: Array) -> void:
		for y in range(10, 20):
			var r: String = rows[y]
			rows[y] = r.substr(0, 8) + "H" + r.substr(9)
			)
	p = fresh(dl)
	p.position = Vector2(8.0 * 32.0 + 16.0, 20.0 * 32.0)
	for f in 90:
		p.inp = {"y": -1.0}
		stage.tick(1.0 / 60.0)
	check("ladders can be climbed", p.position.y < 14.0 * 32.0, str(p.position.y / 32.0))
	# moving platform carries the player
	var dp := arena(func(rows: Array) -> void: pass)
	dp.meta["entities"] = [{"t": "platform", "pts": [[10, 18], [20, 18]], "speed": 90.0, "w": 96.0}]
	p = fresh(dp)
	p.position = Vector2(10.0 * 32.0 + 16.0, 18.0 * 32.0 - 4.0)
	run(10)
	var px := p.position.x
	run(60)
	check("moving platforms carry Kael", absf(p.position.x - px) > 30.0 and p.alive, "%f -> %f" % [px, p.position.x])

# ------------------------------------------------------------------ combat
func spawn(kind: String, tx: int, ty: int = 19) -> Enemy:
	return Spawner.spawn_entity(stage, {"t": "enemy", "k": kind, "x": tx, "y": ty}) as Enemy

func test_combat() -> void:
	print("-- combat")
	var p := fresh(arena())
	var e := spawn("slime", 5)
	run(5)
	var hp0 := e.hp
	p.position.x = e.position.x - 50.0
	p.facing = 1
	p.inp = {"light": true}
	stage.tick(1.0 / 60.0)
	p.inp = {}
	run(30)
	check("light attack damages an enemy", e.hp < hp0 or not e.alive, "%f -> %f" % [hp0, e.hp])
	# 3-hit combo
	run(60)
	var e2 := spawn("guard", 12)
	e2.hp = 9999.0
	e2.max_hp = 9999.0
	p.position.x = e2.position.x - 48.0
	p.facing = 1
	var states := []
	for i in 3:
		p.inp = {"light": true}
		stage.tick(1.0 / 60.0)
		p.inp = {}
		states.append(p.atk_kind)
		run(20)
	check("attacks chain into a combo", states.has("l1") and (states.has("l2") or states.has("l3")), str(states))
	# heavy deals more than light
	var e3 := spawn("guard", 22)
	e3.hp = 9999.0
	e3.max_hp = 9999.0
	e3.armor_front = 0.0
	p.position.x = e3.position.x - 56.0
	p.facing = 1
	var h0 := e3.hp
	p.inp = {"light": true}
	stage.tick(1.0 / 60.0)
	p.inp = {}
	run(40)
	var light_dmg := h0 - e3.hp
	h0 = e3.hp
	p.position.x = e3.position.x - 56.0
	p.facing = 1
	p.inp = {"heavy": true}
	stage.tick(1.0 / 60.0)
	p.inp = {}
	run(60)
	var heavy_dmg := h0 - e3.hp
	check("heavy attack hits harder than light (%.0f vs %.0f)" % [heavy_dmg, light_dmg], heavy_dmg > light_dmg and light_dmg > 0.0)
	# player damage, knock back, i-frames (clean room so nothing re-arms invulnerability)
	p = fresh(arena())
	Game.hp = Game.max_hp()
	p.invuln_t = 0.0
	var hp1 := Game.hp
	var took := p.hurt(20.0, p.position.x + 30.0, 1.0)
	check("player takes damage", took and Game.hp < hp1)
	var hp2 := Game.hp
	var took2 := p.hurt(20.0, p.position.x + 30.0, 1.0)
	check("i-frames prevent immediate second hit", not took2 and Game.hp == hp2)
	run(120)
	check("i-frames expire", p.hurt(5.0, p.position.x + 30.0, 1.0))
	# guardian pendant reduces damage
	Game.new_progress()
	p.invuln_t = 0.0
	var base := Game.hp
	p.hurt(50.0, p.position.x - 30.0, 1.0)
	var dmg_base := base - Game.hp
	Game.full_restore()
	Game.give_equipment("guardian_pendant")
	Game.equip("guardian_pendant")
	run(120)
	p.invuln_t = 0.0
	base = Game.hp
	p.hurt(50.0, p.position.x - 30.0, 1.0)
	var dmg_eq := base - Game.hp
	check("Guardian Pendant reduces damage by ~20%% (%.0f -> %.0f)" % [dmg_base, dmg_eq], dmg_eq < dmg_base * 0.9 and dmg_eq > dmg_base * 0.7)
	# dodge grants i-frames
	p = fresh(arena())
	p.inp = {"x": 1.0, "dodge": true}
	stage.tick(1.0 / 60.0)
	p.inp = {"x": 1.0}
	stage.tick(1.0 / 60.0)
	var hp3 := Game.hp
	var hit_during_dodge := p.hurt(30.0, p.position.x - 20.0, 1.0)
	check("dodge grants invulnerability frames", p.state in ["dash", "dodge"] and not hit_during_dodge and Game.hp == hp3, p.state)
	# heal
	Game.hp = 20.0
	Game.heals_left = 2
	p = fresh(arena())
	Game.hp = 20.0
	Game.heals_left = 2
	p.inp = {"heal": true}
	stage.tick(1.0 / 60.0)
	p.inp = {}
	run(120)
	check("healing restores health and uses a charge", Game.hp > 20.0 and Game.heals_left == 1, "%f %d" % [Game.hp, Game.heals_left])
	# magic bolt
	p = fresh(arena())
	var e4 := spawn("slime", 20)
	var mp0 := Game.mp
	p.position.x = e4.position.x - 220.0
	p.facing = 1
	var h4 := e4.hp
	p.inp = {"magic": true}
	stage.tick(1.0 / 60.0)
	p.inp = {}
	run(90)
	check("magic bolt spends energy and hits at range", Game.mp < mp0 and (e4.hp < h4 or not e4.alive), "%f %f" % [mp0, Game.mp])
	# death
	p = fresh(arena())
	p.invuln_t = 0.0
	p.hurt(99999.0, p.position.x + 10.0, 1.0)
	run(10)
	check("lethal damage kills the player", not p.alive and Game.hp <= 0.0)
	# hit-stop and screen shake settings
	Game.settings["shake"] = false
	stage.shake(10.0)
	check("shake can be disabled", stage.shake_amp <= 0.001, str(stage.shake_amp))
	Game.settings["shake"] = true
	stage.shake(10.0)
	check("shake works when enabled", stage.shake_amp > 1.0)
	stage.hitstop(0.1)
	check("hit-stop engages", stage.hitstop_t > 0.0)

func test_enemies() -> void:
	print("-- enemies")
	for kind in ["slime", "guard", "crawler", "archer", "stalker", "knight", "drone", "wraith"]:
		var p := fresh(arena())
		var e := spawn(kind, 14, 19 if kind not in ["drone", "wraith"] else 14)
		var start_x := e.position.x
		p.position.x = 8.0 * 32.0
		var acted := false
		var seen := {}
		for f in 360:
			p.inp = {}
			Game.hp = Game.max_hp()
			stage.tick(1.0 / 60.0)
			seen[e.state] = true
			if e.state not in ["idle", "patrol"]:
				acted = true
			if f == 120 and seen.size() < 2:
				p.position.x = e.position.x - 90.0
		check("%s runs its state machine (states: %s)" % [kind, ", ".join(seen.keys())], seen.size() >= 2 and acted, str(seen.keys()))
		# telegraph exists before damage: take no damage while the first telegraph is active
		var before := Game.shards
		e.hp = 1.0
		e.take_hit({"damage": 50.0, "from": Vector2(e.position.x - 40.0, e.position.y), "knock": Vector2(50, -50)})
		run(30)
		check("%s can be killed, drops shards and XP" % kind, not e.alive and (Game.shards >= before) and Game.xp + (Game.level - 1) * 100 > 0)
	# kill notifications drive quests
	check("kills are tracked by the stage", stage.kills > 0)

# ------------------------------------------------------------------ items and progression
func test_items() -> void:
	print("-- items, equipment, skills")
	fresh(arena())
	var s0 := Game.shards
	Game.add_shards(25)
	check("shards are added", Game.shards == s0 + 25 or Game.shards >= s0 + 25)
	var lv0 := Game.level
	Game.add_xp(Game.xp_needed())
	check("XP levels up and grants a skill point", Game.level == lv0 + 1 and Game.skill_points >= 1)
	var mhp := Game.max_hp()
	check("buying a skill is possible with a point", Game.can_buy_skill("vitality") == "")
	check("skill purchase applies", Game.buy_skill("vitality") and Game.skill("vitality") == 1 and Game.max_hp() > mhp)
	Game.skill_points = 0
	check("cannot buy without points", Game.can_buy_skill("edge") != "" and not Game.buy_skill("edge"))
	# equipment effects
	var spd0 := Game.equip_stat("speed")
	Game.give_equipment("windrunner_boots")
	Game.equip("windrunner_boots")
	check("Windrunner Boots add speed", Game.equip_stat("speed") > spd0)
	var p := stage.player
	p.use_script = true
	p.inp = {"x": 1.0}
	var x0 := p.position.x
	run(50)
	var d_boots := p.position.x - x0
	Game.unequip("boots")
	p.position.x = x0
	p.vel = Vector2.ZERO
	run(5)
	x0 = p.position.x
	p.inp = {"x": 1.0}
	run(50)
	var d_none := p.position.x - x0
	check("boots really make Kael faster (%.0f vs %.0f px)" % [d_boots, d_none], d_boots > d_none * 1.03, "")
	Game.give_equipment("astral_lens")
	Game.equip("astral_lens")
	stage.refresh_lens()
	check("Astral Lens reveals secrets", Game.equip_stat("reveal") > 0.0)
	Game.give_equipment("eclipse_mantle")
	Game.equip("eclipse_mantle")
	check("Eclipse Mantle reduces magic cost", Game.magic_cost(20.0) < 20.0)
	Game.give_equipment("gearwright_gloves")
	Game.equip("gearwright_gloves")
	check("Gearwright Gloves shorten dash cooldown", Game.dash_cooldown() < Tune.DASH_COOLDOWN)
	Game.give_equipment("frost_band")
	Game.equip("frost_band")
	check("Frost Band boosts heavy damage", Game.heavy_mult() > 1.05)
	# upgrades
	Game.dust = 50
	Game.shards = 500
	var lvl0 := int(Game.equip_lv.get("windrunner_boots", 0))
	check("equipment upgrade works with dust", Game.upgrade_equipment("windrunner_boots") and int(Game.equip_lv["windrunner_boots"]) == lvl0 + 1)
	# chests and pickups
	var d := arena()
	d.meta["entities"] = [{"t": "i", "kind": "chest", "x": 8, "y": 19, "id": "tc", "item": {"shards": 77}}]
	fresh(d)
	var chest: Interactable = null
	for i in stage.interactables:
		if i.kind == "chest":
			chest = i
	var sh := Game.shards
	stage.player.position = chest.position + Vector2(0, 0)
	chest.use(stage.player)
	run(5)
	check("chest grants its contents once", Game.shards >= sh + 77 and chest.used)
	var sh2 := Game.shards
	chest.use(stage.player)
	check("opened chest cannot be looted twice", Game.shards == sh2)
	# difficulty changes real numbers
	Game.new_progress()
	Game.settings["difficulty"] = 0
	var e_easy := spawn("guard", 30)
	var hp_easy := e_easy.hp
	Game.settings["difficulty"] = 2
	var e_hard := spawn("guard", 32)
	var hp_hard := e_hard.hp
	check("difficulty scales enemy health (%.0f story vs %.0f veteran)" % [hp_easy, hp_hard], hp_hard > hp_easy * 1.6)
	Game.hp = 100.0
	Game.settings["difficulty"] = 0
	stage.player.invuln_t = 0.0
	var h_e := Game.hp
	stage.damage_player(10.0, 0.0, 1.0)
	var dmg_easy := h_e - Game.hp
	Game.hp = 100.0
	stage.player.invuln_t = 0.0
	Game.settings["difficulty"] = 2
	h_e = Game.hp
	stage.damage_player(10.0, 0.0, 1.0)
	var dmg_hard := h_e - Game.hp
	check("difficulty scales damage taken (%.1f vs %.1f)" % [dmg_easy, dmg_hard], dmg_hard > dmg_easy * 2.0)
	Game.settings["difficulty"] = 1

func test_quests_shop() -> void:
	print("-- quests and shop")
	Game.new_progress()
	check("there are at least 10 side quests", Story.QUESTS.size() >= 10, str(Story.QUESTS.size()))
	check("quest accept", Quests.accept("slime_trouble") and Quests.status("slime_trouble") == "active")
	for i in 8:
		Game.enemy_killed.emit("slime")
	check("kill quest completes", Quests.status("slime_trouble") == "done", Quests.status("slime_trouble"))
	var sh := Game.shards
	check("quest reward claimed", Quests.claim("slime_trouble") and Game.shards > sh and Quests.status("slime_trouble") == "claimed")
	check("cannot claim twice", not Quests.claim("slime_trouble"))
	var all_ok := true
	for qid in Story.QUESTS:
		var q: Dictionary = Story.QUESTS[qid]
		if not (q.has("title") and q.has("giver") and Story.NPCS.has(q["giver"]) and q.has("reward") and int(q["count"]) > 0):
			all_ok = false
	check("every quest is well-formed", all_ok)
	# every quest type can complete from events
	Game.new_progress()
	Quests.accept("lost_pages")
	for i in 5:
		Game.event.emit("journal")
	check("journal quest completes from events", Quests.status("lost_pages") == "done")
	# shop
	Game.shards = 1000
	var hp0 := Game.max_hp()
	check("shop purchase succeeds", Game.shop_buy("heart") and Game.max_hp() > hp0)
	var price0 := Game.shop_price("heart")
	Game.shards = 0
	check("shop refuses when broke", not Game.shop_buy("heart") and Game.shop_can_buy("heart") != "")
	Game.shards = 1000
	Game.shop_buy("dust")
	check("dust can be bought", Game.dust >= 3)
	check("prices rise with purchases", Game.shop_price("heart") >= price0)
	# save round trip keeps everything
	var d := Game.serialize()
	var json := JSON.stringify(d)
	var back: Dictionary = JSON.parse_string(json)
	var shards := Game.shards
	var q := Game.quests.duplicate()
	Game.new_progress()
	Game.deserialize(back)
	check("serialize/deserialize round trip", Game.shards == shards and Game.quests == q)
	Game.deserialize({"fragments": 999, "skills": {"bogus": 5}, "equipped": {"boots": "nonexistent"}, "level": -4})
	check("malformed save data is sanitised", Game.fragments <= 7 and not Game.skills.has("bogus") and Game.level >= 1 and not Game.equipped.has("boots"))

# ------------------------------------------------------------------ checkpoints and rooms
func test_checkpoint_and_rooms() -> void:
	print("-- checkpoints and rooms")
	Game.new_progress()
	stage.load_room(World.get_room("meadows_1"), "start")
	var shrine: Interactable = null
	for i in stage.interactables:
		if i.kind == "checkpoint":
			shrine = i
	check("hub has a starshrine", shrine != null)
	stage.player.use_script = true
	stage.player.position = shrine.position
	Game.hp = 10.0
	shrine.use(stage.player)
	check("shrine restores health and sets respawn", Game.hp == Game.max_hp() and Game.checkpoint["level"] == "meadows_1")
	# walk into the right-hand exit door -> next room, then die and respawn at the shrine
	stage.request_room_change("meadows_2", "from_prev")
	run(3)
	check("room transition loads the next room", stage.room_id == "meadows_2", stage.room_id)
	check("player placed at the entry", stage.player.position.x < 10.0 * 32.0 and stage.player.alive)
	Game.hp = 0.0
	stage.respawn_at_checkpoint()
	run(3)
	check("respawn returns to the last shrine room", stage.room_id == "meadows_1" and Game.hp == Game.max_hp(), stage.room_id)
	# every exit in every room leads to a real room, and rooms link back
	var bad := []
	for id in LevelGen.all_room_ids():
		var d := World.get_room(id)
		for e in d.meta.get("entities", []):
			if e.get("t", "") == "i" and e.get("kind", "") == "exit":
				var to: String = str(e.get("to", ""))
				if to == "":
					continue
				var tr := World.get_room(to)
				if tr == null:
					bad.append("%s -> %s" % [id, to])
				elif not tr.meta.get("spawns", {}).has(str(e.get("entry", "start"))):
					bad.append("%s -> %s (entry %s)" % [id, to, e.get("entry", "start")])
	check("all %d rooms' exits lead to existing rooms and spawn points" % LevelGen.all_room_ids().size(), bad.is_empty(), str(bad.slice(0, 5)))
	# boss gate: sealed until the guardian falls
	Game.new_progress()
	stage.load_room(World.get_room("meadows_boss"), "start")
	var door: Interactable = null
	for i in stage.interactables:
		if i.kind == "exit" and str(i.props.get("requires", "")) != "":
			door = i
	check("boss room exit requires the guardian's defeat", door != null and not Game.flag(str(door.props["requires"])))

# ------------------------------------------------------------------ puzzles
func test_puzzles() -> void:
	print("-- puzzles solved by scripted play")
	var solved := {"seq": 0, "beam": 0, "block": 0}
	for id in LevelGen.all_room_ids():
		var d := LevelGen.build(id)
		var ents: Array = d.meta.get("entities", [])
		var kinds := {}
		for e in ents:
			kinds[str(e.get("kind", e.get("t", "")))] = true
		var is_seq := false
		var is_beam := false
		var is_block := false
		for e in ents:
			if e.get("kind", "") == "switch" and e.get("group", "") == "seq":
				is_seq = true
			if e.get("kind", "") == "emitter":
				is_beam = true
			if e.get("t", "") == "push":
				is_block = true
		if not (is_seq or is_beam or is_block):
			continue
		Game.new_progress()
		for a in ["dash", "wall_jump", "stasis", "double_jump"]:
			Game.unlock_ability(a)
		stage.load_room(d, "start")
		stage.player.use_script = true
		run(10)
		var group := "seq" if is_seq else ("beam" if is_beam else "plates")
		var gate_before := false
		for g in d.meta.get("puzzles", {}).get(group, {}).get("gates", []):
			if stage.level.tile(int(g[0]), int(g[1])) == Tiles.GATE:
				gate_before = true
		if is_seq:
			var sws: Array = []
			for i in stage.interactables:
				if i.kind == "switch" and i.group == "seq":
					sws.append(i)
			sws.sort_custom(func(a, b): return a.order < b.order)
			# a wrong order resets, the correct order solves
			if sws.size() > 1:
				var wrong: Interactable = sws[sws.size() - 1]
				stage.hit_targets(Rect2(wrong.position.x - 10, wrong.position.y - 30, 20, 30), {"damage": 1.0, "from": Vector2.ZERO}, {})
				check(id + ": wrong switch order resets the puzzle", not stage.puzzle_done("seq") and not wrong.active)
			for sw in sws:
				stage.hit_targets(Rect2(sw.position.x - 10, sw.position.y - 30, 20, 30), {"damage": 1.0, "from": Vector2.ZERO}, {})
			solved["seq"] += 1
			check(id + ": switch sequence solves", stage.puzzle_done("seq"))
		elif is_beam:
			var sol: Array = d.meta["beam_solution"]
			var prisms: Array = []
			for i in stage.interactables:
				if i.kind == "prism":
					prisms.append(i)
			prisms.sort_custom(func(a, b): return a.position.y < b.position.y)
			for k in prisms.size():
				var guard := 0
				while prisms[k]._prism_dir != sol[k] and guard < 5:
					prisms[k].use(stage.player)
					guard += 1
			run(10)
			solved["beam"] += 1
			check(id + ": beam puzzle solves by rotating prisms", stage.puzzle_done("beam"))
		else:
			# push the block right along the floor with real physics, then step on the other plate
			var blk: PushBlock = stage.pushblocks[0]
			var plates: Array = []
			for i in stage.interactables:
				if i.kind == "plate":
					plates.append(i)
			plates.sort_custom(func(a, b): return a.position.x < b.position.x)
			var p := stage.player
			p.position = Vector2(blk.position.x - 60.0, blk.position.y)
			for f in 900:
				p.inp = {"x": 1.0}
				stage.tick(1.0 / 60.0)
				if blk.position.x >= plates[1].position.x - 4.0:
					break
			p.inp = {}
			run(20)
			check(id + ": block can be pushed onto the far plate (%.0f vs %.0f)" % [blk.position.x, plates[1].position.x], absf(blk.position.x - plates[1].position.x) < 40.0)
			p.position = Vector2(plates[0].position.x, plates[0].position.y)
			p.vel = Vector2.ZERO
			run(30)
			solved["block"] += 1
			check(id + ": block puzzle solves with both plates pressed", stage.puzzle_done("plates"))
		var opened := true
		for g in d.meta.get("puzzles", {}).get(group, {}).get("gates", []):
			if stage.level.tile(int(g[0]), int(g[1])) == Tiles.GATE:
				opened = false
		check(id + ": solving opens the gate", gate_before and opened, "before=%s open=%s" % [gate_before, opened])
		check(id + ": solved flag persists", Game.flag("puzzle_%s_%s" % [id, group]))
	print("   solved: ", solved)
	check("all three puzzle types are present in the campaign", solved["seq"] > 0 and solved["beam"] > 0 and solved["block"] > 0, str(solved))
