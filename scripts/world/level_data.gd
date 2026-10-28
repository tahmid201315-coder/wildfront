class_name LevelData
extends RefCounted
## Plain description of one room: tile rows plus metadata. Produced by LevelGen or hand-written.

var id: String = ""
var region: String = "meadows"
var title: String = ""
var rows: PackedStringArray = PackedStringArray()
var w: int = 0
var h: int = 0
var is_boss_arena: bool = false
var boss_id: String = ""
var music: String = ""
var meta: Dictionary = {}     # doors, chests, npcs, journals, platforms, hints ...
var main_path_len: int = 0


func finalize() -> void:
	h = rows.size()
	w = 0
	for r in rows:
		w = maxi(w, r.length())
	var fixed := PackedStringArray()
	for r in rows:
		fixed.append(r + ".".repeat(w - r.length()))
	rows = fixed


func char_at(x: int, y: int) -> String:
	if y < 0 or y >= h or x < 0 or x >= w:
		return "#"
	return rows[y][x]


func set_char(x: int, y: int, c: String) -> void:
	if y < 0 or y >= h or x < 0 or x >= w:
		return
	rows[y] = rows[y].substr(0, x) + c + rows[y].substr(x + 1)
