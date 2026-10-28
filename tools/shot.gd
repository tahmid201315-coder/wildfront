extends Node
## Developer tool: renders a showcase room with Kael and every enemy, saves PNGs to /tmp/shots.
const OUT := "/tmp/shots/"
var stage: Stage

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var region: String = OS.get_environment("REGION") if OS.get_environment("REGION") != "" else "meadows"
	stage = Stage.new()
	stage.headless_instant = true
	add_child(stage)
	await get_tree().process_frame
	var rows: Array = []
	for y in 22:
		if y < 18:
			rows.append("#" + ".".repeat(46) + "#")
		else:
			rows.append("#".repeat(48))
	rows[14] = "#.....=======......###...........=====.............#"
	var d := LevelData.new()
	d.id = "shot"
	d.region = region
	var r := PackedStringArray(rows)
	d.rows = r
	var ents: Array = []
	var kinds := ["slime", "guard", "crawler", "archer", "stalker", "knight", "drone", "wraith"]
	for i in kinds.size():
		ents.append({"t": "enemy", "k": kinds[i], "x": 14 + i * 3, "y": 17})
	ents.append({"t": "i", "kind": "checkpoint", "x": 6, "y": 17, "id": "a"})
	ents.append({"t": "i", "kind": "chest", "x": 9, "y": 17, "id": "c1"})
	ents.append({"t": "i", "kind": "npc", "x": 11, "y": 17, "npc": "merchant"})
	d.meta = {"spawns": {"start": [3, 17]}, "entities": ents}
	d.finalize()
	Game.new_progress()
	Game.set_flag("x")
	stage.load_room(d, "start")
	var p := stage.player
	p.use_script = true
	for i in 30: stage.tick(1.0 / 60.0)
	p.inp = {"x": 1.0}
	for i in 40: stage.tick(1.0 / 60.0)
	await _shot("run")
	p.inp = {"jump_pressed": true, "jump_down": true}
	stage.tick(1.0 / 60.0)
	p.inp = {"jump_down": true}
	for i in 14: stage.tick(1.0 / 60.0)
	await _shot("jump")
	p.inp = {}
	for i in 60: stage.tick(1.0 / 60.0)
	p.inp = {"light": true}
	stage.tick(1.0 / 60.0)
	p.inp = {}
	for i in 7: stage.tick(1.0 / 60.0)
	await _shot("attack")
	get_tree().quit()

func _shot(n: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(OUT + n + ".png")
