extends Node
## Headless core tests. Run: godot --headless --path . -s tests/test_core.gd

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


func make_room(rows: Array, meta: Dictionary = {}) -> LevelData:
	var d := LevelData.new()
	d.id = "t_%d" % randi()
	d.region = "meadows"
	d.rows = PackedStringArray(rows)
	d.meta = meta
	d.finalize()
	return d


func _ready() -> void:
	await get_tree().process_frame
	stage = Stage.new()
	stage.headless_instant = true
	add_child(stage)
	await get_tree().process_frame
	await test_movement()
	print("\n== %d passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)


func run(frames: int) -> void:
	for i in frames:
		stage.tick(1.0 / 60.0)


func test_movement() -> void:
	print("-- movement")
	var rows: Array = []
	for y in 20:
		rows.append("#" + ".".repeat(48) + "#" if y < 17 else "#".repeat(50))
	var d := make_room(rows, {"spawns": {"start": [3, 16]}})
	Game.new_progress()
	stage.load_room(d, "start")
	var p := stage.player
	p.use_script = true
	p.inp = {}
	run(20)
	check("player settles on floor", p.on_floor, str(p.position))
	var x0 := p.position.x
	p.inp = {"x": 1.0}
	run(30)
	check("runs right", p.position.x > x0 + 80.0, str(p.position.x - x0))
	p.inp = {}
	run(30)
	var y0 := p.position.y
	p.inp = {"jump_pressed": true, "jump_down": true}
	run(1)
	p.inp = {"jump_down": true}
	run(25)
	check("jump rises", p.position.y < y0 - 60.0, str(y0 - p.position.y))
