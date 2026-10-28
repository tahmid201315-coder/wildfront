extends Node
## Generates every room in the campaign and verifies reachability.
var passed := 0
var failed := 0

func check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		printerr("  FAIL ", name, "  ", detail)

func _ready() -> void:
	var ids := LevelGen.all_room_ids()
	printerr("rooms: %d" % ids.size())
	var t0 := Time.get_ticks_msec()
	for id in ids:
		var d := LevelGen.build(id)
		check(id + " builds", d != null)
		if d == null:
			continue
		var r := Verifier.check_room(d)
		check(id + " reachable", r["ok"], str(r["problems"]))
		if r["ok"]:
			printerr("  ok   ", id, " (%dx%d, %d cells)" % [d.w, d.h, r["nodes"]])
	printerr("verify time %d ms" % (Time.get_ticks_msec() - t0))
	printerr("\n== %d passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)
