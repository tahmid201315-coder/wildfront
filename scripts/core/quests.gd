class_name Quests
extends RefCounted
## Side-quest bookkeeping on top of Game.quests (id -> "active"|"done"|"claimed") and Game.quest_progress (id -> count).

static func status(id: String) -> String:
	return str(Game.quests.get(id, "new"))


static func accept(id: String) -> bool:
	if not Story.QUESTS.has(id) or Game.quests.has(id):
		return false
	Game.quests[id] = "active"
	Game.quest_progress[id] = 0
	_seed_progress(id)
	Game.toast.emit("Quest accepted: " + str(Story.QUESTS[id]["title"]), "quest")
	Game.quest_changed.emit()
	_check(id)
	return true


static func _seed_progress(id: String) -> void:
	var q: Dictionary = Story.QUESTS[id]
	# some quests count things already done before acceptance
	match q["type"]:
		"journals":
			var n := 0
			for k in Game.flags:
				if str(k).begins_with("journal_"):
					n += 1
			Game.quest_progress[id] = n
		"shrines":
			var n2 := 0
			for k in Game.flags:
				if str(k).begins_with("shrine_"):
					n2 += 1
			Game.quest_progress[id] = n2
		"bosses":
			Game.quest_progress[id] = Game.bosses.size()
		"chests":
			var n3 := 0
			for k in Game.flags:
				if str(k).begins_with("chest_"):
					n3 += 1
			Game.quest_progress[id] = n3


static func bump(type: String, target: String, amount: int = 1) -> void:
	for id in Game.quests:
		if Game.quests[id] != "active":
			continue
		var q: Dictionary = Story.QUESTS[id]
		if q["type"] != type:
			continue
		if q["target"] != "" and q["target"] != target:
			continue
		Game.quest_progress[id] = int(Game.quest_progress.get(id, 0)) + amount
		_check(id)
	Game.quest_changed.emit()


static func _check(id: String) -> void:
	var q: Dictionary = Story.QUESTS[id]
	if Game.quests.get(id) == "active" and int(Game.quest_progress.get(id, 0)) >= int(q["count"]):
		Game.quests[id] = "done"
		Game.toast.emit("Quest complete: %s. Return to %s." % [q["title"], Story.NPCS[q["giver"]]["name"]], "quest")
		Game.quest_changed.emit()


static func claim(id: String) -> bool:
	if Game.quests.get(id) != "done":
		return false
	var r: Dictionary = Story.QUESTS[id]["reward"]
	Game.quests[id] = "claimed"
	if r.has("shards"):
		Game.add_shards(int(r["shards"]))
	if r.has("dust"):
		Game.dust += int(r["dust"])
	if r.has("skill_point"):
		Game.skill_points += int(r["skill_point"])
	if r.has("heart"):
		Game.bonus_hp += 10
		Game.heart_pieces += 3
	Game.toast.emit("Reward claimed: " + reward_text(r), "good")
	Game.stats_changed.emit()
	Game.progress_changed.emit()
	Game.quest_changed.emit()
	return true


static func reward_text(r: Dictionary) -> String:
	var parts: Array = []
	if r.has("shards"): parts.append("%d shards" % int(r["shards"]))
	if r.has("dust"): parts.append("%d dust" % int(r["dust"]))
	if r.has("skill_point"): parts.append("%d skill point(s)" % int(r["skill_point"]))
	if r.has("heart"): parts.append("+10 max health")
	return ", ".join(parts)


static func available_for(giver: String) -> Array:
	var out: Array = []
	for id in Story.QUESTS:
		if Story.QUESTS[id]["giver"] == giver and status(id) in ["new", "active", "done"]:
			out.append(id)
	return out


static func on_kill(kind: String) -> void:
	bump("kill", kind)


static func on_event(id: String) -> void:
	match id:
		"chest": bump("chests", "")
		"journal": bump("journals", "")
		"checkpoint":
			for qid in Game.quests:
				if Game.quests[qid] == "active" and Story.QUESTS[qid]["type"] == "shrines":
					_seed_progress(qid)
					_check(qid)
			Game.quest_changed.emit()
		"boss": bump("bosses", "")


static func on_shards(n: int) -> void:
	bump("shards", "", n)


static func count_done() -> int:
	var n := 0
	for id in Game.quests:
		if Game.quests[id] in ["done", "claimed"]:
			n += 1
	return n
