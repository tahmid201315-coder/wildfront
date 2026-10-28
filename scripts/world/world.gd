class_name World
extends RefCounted
## Room registry. Rooms are built lazily (deterministic per id) and cached.

static var _cache: Dictionary = {}
static var _extra: Dictionary = {}     # id -> LevelData registered by tests


static func register(d: LevelData) -> void:
	_extra[d.id] = d


static func clear_cache() -> void:
	_cache.clear()


static func get_room(id: String) -> LevelData:
	if _extra.has(id):
		return _extra[id]
	if _cache.has(id):
		return _cache[id]
	var d: LevelData = LevelGen.build(id)
	if d != null:
		_cache[id] = d
	return d
