extends Node
func _ready() -> void:
	var id := OS.get_environment("ROOM")
	var d := LevelGen.build(id)
	var rows := d.rows.duplicate()
	for e in d.meta["entities"]:
		if e["t"] == "i" and e.has("x"):
			var c := "?"
			match e["kind"]:
				"checkpoint": c = "C"
				"chest": c = "$"
				"exit": c = "E"
				"switch": c = "S"
				"journal": c = "J"
				"npc": c = "N"
				"hint": c = "h"
				"prism": c = "P"
				"emitter": c = "M"
				"target": c = "O"
				"plate": c = "_"
			var r: String = rows[e["y"]]
			rows[e["y"]] = r.substr(0, e["x"]) + c + r.substr(e["x"] + 1)
		elif e["t"] == "enemy":
			var r2: String = rows[e["y"]]
			rows[e["y"]] = r2.substr(0, e["x"]) + "e" + r2.substr(e["x"] + 1)
	var v := Verifier.new(d, d.meta.get("abilities", []))
	v.gates_closed = false
	v.x_closed = true
	v.build(d.meta.get("platform_nodes", []))
	var sn: Array = d.meta["spawns"]["from_next"]
	var rn := v.reachable_from(v.key(sn[0], sn[1]))
	for k in v.nodes:
		if not rn.has(k):
			var yy: int = k / d.w
			var xx: int = k % d.w
			var rr: String = rows[yy]
			if rr[xx] == ".":
				rows[yy] = rr.substr(0, xx) + "x" + rr.substr(xx + 1)
	var out := ""
	for y in rows.size():
		out += "%2d %s\n" % [y, rows[y]]
	var f := FileAccess.open("/tmp/room.txt", FileAccess.WRITE)
	f.store_string(out)
	f.close()
	get_tree().quit()
