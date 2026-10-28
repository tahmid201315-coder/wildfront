class_name Cv
extends RefCounted
## Tile canvas used by the room generator. Characters follow Tiles.CHAR_TO_TILE.

var w: int
var h: int
var g: PackedByteArray = PackedByteArray()
var entities: Array = []
var puzzles: Dictionary = {}
var spawns: Dictionary = {}
var spans: Array = []          # flat floor spans {x0, x1, y} where things can be placed
var meta: Dictionary = {}


func _init(width: int, height: int) -> void:
	w = width
	h = height
	g.resize(w * h)
	for i in g.size():
		g[i] = 46   # '.'


func get_c(x: int, y: int) -> String:
	if x < 0 or x >= w or y < 0:
		return "#"
	if y >= h:
		return "."
	return char(g[y * w + x])


func set_c(x: int, y: int, c: String) -> void:
	if x < 0 or x >= w or y < 0 or y >= h:
		return
	g[y * w + x] = c.unicode_at(0)


func fill(x0: int, y0: int, x1: int, y1: int, c: String) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			set_c(x, y, c)


func is_solid_c(x: int, y: int) -> bool:
	return get_c(x, y) in ["#", "B", "X", "I", "G"]


func ent(d: Dictionary) -> void:
	entities.append(d)


func to_rows() -> PackedStringArray:
	var rows := PackedStringArray()
	for y in h:
		rows.append(g.slice(y * w, (y + 1) * w).get_string_from_ascii())
	return rows
