extends Node
## Data-driven quest tracking (autoload "Quests").

signal quest_updated
signal quest_completed(id: String)
signal quest_started(id: String)

var active: Dictionary = {}      # id -> {"progress": [float, ...]}
var completed: Dictionary = {}   # id -> true


func _ready() -> void:
	refresh_unlocks(false)


func reset() -> void:
	active = {}
	completed = {}
	refresh_unlocks(false)


func is_unlocked(id: String) -> bool:
	var q: Dictionary = Data.quests[id]
	if Game.level < int(q["level"]):
		return false
	for req in q["requires"]:
		if not completed.has(req):
			return false
	return true


func refresh_unlocks(announce: bool = true) -> void:
	for id in Data.quest_order:
		if completed.has(id) or active.has(id):
			continue
		if is_unlocked(id):
			var prog: Array = []
			for o in Data.quests[id]["objectives"]:
				prog.append(0.0)
			active[id] = {"progress": prog}
			_sync_existing_progress(id)
			if announce:
				quest_started.emit(id)
				Game.toast("New quest: " + Data.quests[id]["name"], "quest")
	quest_updated.emit()
	for id in active.keys():
		if active.has(id) and _all_done(id):
			complete(id)


## A quest can unlock after the player already did something it asks for (discovering a
## species, entering a region, befriending, building a shelter). Count that so nobody is stuck.
func _sync_existing_progress(id: String) -> void:
	var q: Dictionary = Data.quests[id]
	var prog: Array = active[id]["progress"]
	for i in q["objectives"].size():
		var o: Dictionary = q["objectives"][i]
		var have := 0.0
		match String(o["type"]):
			"discover":
				if o["target"] == "":
					have = float(Game.discovered_species.size())
				elif Game.discovered_species.has(o["target"]):
					have = 1.0
			"region":
				have = 1.0 if Game.visited_regions.has(o["target"]) else 0.0
			"landmark":
				have = 1.0 if Game.found_landmarks.has(o["target"]) else 0.0
			"befriend":
				have = float(Game.creatures.size())
			"build_shelter":
				if Game.world != null and is_instance_valid(Game.world) and Game.world.get("build_manager") != null and Game.world.build_manager.shelter_exists():
					have = 1.0
		prog[i] = minf(have, float(o["count"]))


## Report a gameplay event. type: walk, look, gather, craft, place, discover, befriend, ability,
## harvest, defeat, region, landmark, open_inventory, build_shelter, save, restore_core
func notify_event(type: String, key: String = "", amount: float = 1.0) -> void:
	var finished: Array = []
	var changed := false
	for id in active:
		var q: Dictionary = Data.quests[id]
		var prog: Array = active[id]["progress"]
		for i in q["objectives"].size():
			var o: Dictionary = q["objectives"][i]
			if o["type"] != type:
				continue
			if o["target"] != "" and o["target"] != key:
				continue
			if prog[i] >= float(o["count"]):
				continue
			prog[i] = minf(prog[i] + amount, float(o["count"]))
			changed = true
		if _all_done(id):
			finished.append(id)
	for id in finished:
		complete(id)
	if changed:
		quest_updated.emit()


func _all_done(id: String) -> bool:
	var q: Dictionary = Data.quests[id]
	var prog: Array = active[id]["progress"]
	for i in q["objectives"].size():
		if prog[i] < float(q["objectives"][i]["count"]):
			return false
	return true


func complete(id: String) -> void:
	if completed.has(id) or not active.has(id):
		return  # rewards are granted exactly once
	active.erase(id)
	completed[id] = true
	var q: Dictionary = Data.quests[id]
	var rw: Dictionary = q["reward"]
	for item_id in rw.get("items", {}):
		Game.give_item(item_id, int(rw["items"][item_id]))
	Game.toast("Quest complete: " + q["name"], "quest")
	Sfx.play("quest")
	quest_completed.emit(id)
	Game.add_xp(int(rw.get("xp", 0)), "quest")
	refresh_unlocks(true)
	if Game.world and Game.world.has_method("save_now"):
		Game.world.save_now(false)


func tracked() -> String:
	for id in Data.quest_order:
		if active.has(id):
			return id
	return ""


func objective_text(id: String, i: int) -> String:
	var o: Dictionary = Data.quests[id]["objectives"][i]
	var p: float = active[id]["progress"][i] if active.has(id) else (float(o["count"]) if completed.has(id) else 0.0)
	if o["type"] == "walk" or o["type"] == "look":
		return "%s (%d%%)" % [o["text"], int(100.0 * p / float(o["count"]))]
	if float(o["count"]) <= 1.0:
		return "%s %s" % [o["text"], "(done)" if p >= 1.0 else ""]
	return "%s (%d/%d)" % [o["text"], int(p), int(o["count"])]


func serialize() -> Dictionary:
	var a := {}
	for id in active:
		a[id] = active[id]["progress"].duplicate()
	return {"active": a, "completed": completed.keys()}


func deserialize(d: Dictionary) -> void:
	active = {}
	completed = {}
	for id in d.get("completed", []):
		if Data.quests.has(id):
			completed[id] = true
	var a: Dictionary = d.get("active", {})
	for id in a:
		if Data.quests.has(id) and not completed.has(id):
			var prog: Array = []
			var saved: Array = a[id]
			for i in Data.quests[id]["objectives"].size():
				prog.append(float(saved[i]) if i < saved.size() else 0.0)
			active[id] = {"progress": prog}
	refresh_unlocks(false)
