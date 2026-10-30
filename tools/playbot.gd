extends Node
## Developer tool: plays rooms with a simple bot through the real Main scene and saves periodic screenshots + a report to /tmp/pb/.
## ROOMS="meadows_1,meadows_2" TIMEOUT=60
var m: Node
var report: Array = []

func snap(n: String) -> void:
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("/tmp/pb/%s.png" % n)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/pb/")
	Engine.time_scale = 4.0
	Save.base_dir = "user://pb/"
	DirAccess.make_dir_recursive_absolute("user://pb/")
	m = load("res://scenes/main.tscn").instantiate()
	add_child(m)
	await get_tree().physics_frame
	m._on_new_game(0, 1)
	m.cutscene.skip()
	await get_tree().create_timer(1.5).timeout
	for a in Game.ABILITY_NAMES:
		Game.unlock_ability(a)
	var rooms: PackedStringArray = OS.get_environment("ROOMS").split(",")
	var tmo := float(OS.get_environment("TIMEOUT")) if OS.get_environment("TIMEOUT") != "" else 60.0
	for rid in rooms:
		await play_room(rid, tmo)
	var f := FileAccess.open("/tmp/pb/report.txt", FileAccess.WRITE)
	f.store_string("\n".join(report))
	f.close()
	print("\n".join(report))
	get_tree().quit()

func exit_x(d: LevelData) -> float:
	var best := -1.0
	for e in d.meta.get("entities", []):
		if e.get("kind", "") == "exit" and int(e.get("x", 0)) > d.w / 2:
			best = float(e["x"]) * 32.0
	return best

func play_room(rid: String, tmo: float) -> void:
	var d := World.get_room(rid)
	Game.god = true
	m.stage.change_room(rid, "start")
	await get_tree().create_timer(0.3).timeout
	var p: Player = m.stage.player
	var goal := exit_x(d)
	if d.is_boss_arena:
		goal = 20.0 * 32.0
	var t := 0.0
	var last_x := p.position.x
	var stuck_t := 0.0
	var shots := 0
	var next_shot := 3.0
	var seq_done := false
	var result := "TIMEOUT"
	var jump_hold := 0.0
	while t < tmo:
		await get_tree().physics_frame
		var dt := 1.0 / 60.0
		t += dt
		if m.stage.room_id != rid:
			result = "LEFT ROOM -> " + m.stage.room_id
			break
		var inp := {"x": 1.0 if p.position.x < goal else -1.0}
		# attack nearby enemies
		for e in m.stage.enemies:
			if is_instance_valid(e) and e.alive and absf(e.position.x - p.position.x) < 70.0 and absf(e.position.y - p.position.y) < 60.0:
				inp["light"] = int(t * 8.0) % 2 == 0
		# jump when blocked, near a drop, or periodically
		var ahead := Rect2(p.position.x + 20.0 * inp["x"] - 8.0, p.position.y - 24.0, 16.0, 20.0)
		var floor_ahead := Rect2(p.position.x + 34.0 * inp["x"] - 6.0, p.position.y + 4.0, 12.0, 40.0)
		var blocked: bool = m.stage.level.rect_hits_solid(ahead)
		var no_floor: bool = not m.stage.level.rect_hits_solid(floor_ahead)
		if p.on_floor and (blocked or no_floor):
			inp["jump_pressed"] = true
			jump_hold = 0.45
		if jump_hold > 0.0:
			inp["jump_down"] = true
			jump_hold -= dt
			if not p.on_floor and no_floor:
				inp["dodge"] = true
		if p.state == "climb" or (m.stage.level.tile(int(p.position.x / 32.0), int((p.position.y - 8.0) / 32.0)) == Tiles.LADDER):
			inp["y"] = -1.0
		p.inp = inp
		p.use_script = true
		if absf(p.position.x - last_x) > 6.0:
			last_x = p.position.x
			stuck_t = 0.0
		else:
			stuck_t += dt
		if stuck_t > 8.0:
			result = "STUCK at x=%.0f y=%.0f (tile %d,%d)" % [p.position.x, p.position.y, int(p.position.x / 32.0), int(p.position.y / 32.0)]
			await snap(rid + "_stuck")
			break
		if t >= next_shot and shots < 3:
			shots += 1
			next_shot += 6.0
			await snap("%s_%d" % [rid, shots])
		if not p.alive:
			m.stage.respawn_at_checkpoint()
			break
	report.append("%s: %s after %.0fs sim, kills so far %d" % [rid, result, t, m.stage.kills])
	p.use_script = false
