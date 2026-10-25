extends Node
## Autoload "Quests": data-driven quests whose progress is derived from persistent game stats,
## so objectives completed before a quest unlocks still count and nothing can get stuck.

signal quest_updated
signal quest_completed(id: String)
signal quest_started(id: String)

var completed: Dictionary = {}     # id -> true (rewards granted exactly once)
var known: Dictionary = {}         # id -> true (announced as started)
var tracked_id: String = ""
var _busy := false


func _ready() -> void:
	Game.progress_changed.connect(refresh)
	Inv.changed.connect(refresh)


func reset() -> void:
	completed = {}
	known = {}
	tracked_id = ""
	refresh(false)


func is_unlocked(id: String) -> bool:
	var q: Dictionary = Data.quests[id]
	if Game.level < int(q["level"]):
		return false
	for req in q["requires"]:
		if not completed.has(req):
			return false
	return true


func is_active(id: String) -> bool:
	return Data.quests.has(id) and not completed.has(id) and is_unlocked(id)


func active_ids() -> Array:
	var out: Array = []
	for id in Data.quest_order:
		if is_active(id):
			out.append(id)
	return out


## Current numeric progress for one objective.
func objective_value(o: Dictionary) -> float:
	var key: String = o["key"]
	match String(o["type"]):
		"gather": return float(Game.stat("gather:" + key))
		"craft": return float(Game.stat("craft:" + key))
		"place": return float(Game.stat("place:" + key))
		"kill": return float(Game.stat("kill:" + key))
		"interact": return float(Game.stat("interact:" + key))
		"shelter": return 1.0 if Game.flag("shelter") else 0.0
		"log": return 1.0 if Game.logs_read.has(key) else 0.0
		"region": return 1.0 if Game.regions_seen.has(key) else 0.0
		"site": return 1.0 if Game.sites_found.has(key) else 0.0
		"defeat": return 1.0 if Game.bosses_defeated.has(key) else 0.0
		"have": return float(Inv.count(key))
		"open": return float(int(Game.opened.get(key, 0)))
	return 0.0


func objective_done(o: Dictionary) -> bool:
	return objective_value(o) >= float(o["count"])


func progress(id: String) -> Array:
	var out: Array = []
	for o in Data.quests[id]["objectives"]:
		out.append(minf(objective_value(o), float(o["count"])))
	return out


func all_done(id: String) -> bool:
	for o in Data.quests[id]["objectives"]:
		if not objective_done(o):
			return false
	return true


func refresh(announce: bool = true) -> void:
	if _busy:
		return
	_busy = true
	var changed := true
	var guard := 0
	while changed and guard < 40:
		changed = false
		guard += 1
		for id in Data.quest_order:
			if completed.has(id) or not is_unlocked(id):
				continue
			if not known.has(id):
				known[id] = true
				if announce:
					quest_started.emit(id)
					Game.toast("New quest: " + Data.quests[id]["name"], "quest")
			if all_done(id):
				_complete(id)
				changed = true
	if tracked_id == "" or completed.has(tracked_id) or not is_unlocked(tracked_id):
		tracked_id = _default_tracked()
	_busy = false
	quest_updated.emit()


func _default_tracked() -> String:
	for id in Data.quest_order:
		if is_active(id) and Data.quests[id]["main"]:
			return id
	for id in Data.quest_order:
		if is_active(id):
			return id
	return ""


func track(id: String) -> void:
	if is_active(id):
		tracked_id = id
		quest_updated.emit()


func _complete(id: String) -> void:
	if completed.has(id):
		return
	completed[id] = true
	var q: Dictionary = Data.quests[id]
	var rw: Dictionary = q["reward"]
	for item_id in rw.get("items", {}):
		Game.give_item(item_id, int(rw["items"][item_id]))
	Game.toast("Quest complete: " + q["name"], "quest")
	Sfx.play("quest")
	quest_completed.emit(id)
	Game.add_xp(int(rw.get("xp", 0)), "quest")
	if Game.world and Game.world.has_method("on_quest_completed"):
		Game.world.on_quest_completed(id)


func objective_text(id: String, i: int) -> String:
	var o: Dictionary = Data.quests[id]["objectives"][i]
	var v := minf(objective_value(o), float(o["count"]))
	if int(o["count"]) > 1:
		return "%s (%d/%d)" % [o["text"], int(v), int(o["count"])]
	return str(o["text"])


func serialize() -> Dictionary:
	return {"completed": completed.keys(), "known": known.keys(), "tracked": tracked_id}


func deserialize(d: Dictionary) -> void:
	completed = {}
	known = {}
	for k in d.get("completed", []):
		if Data.quests.has(str(k)):
			completed[str(k)] = true
	for k in d.get("known", []):
		if Data.quests.has(str(k)):
			known[str(k)] = true
	tracked_id = str(d.get("tracked", ""))
	refresh(false)
