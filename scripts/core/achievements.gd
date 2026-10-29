class_name Achievements
extends RefCounted
## Achievements are stored as flags ("ach_<id>") and counters in quest_progress ("stat_<name>"), so they save with the game
## and survive New Game+. Unlocking cosmetic scarves is tied to some of them.

const LIST := {
	"first_blood": {"name": "First Blood", "desc": "Defeat your first enemy."},
	"slayer": {"name": "Slayer", "desc": "Defeat 100 enemies. Unlocks the Gold scarf."},
	"guardian": {"name": "Guardian Slayer", "desc": "Defeat a guardian."},
	"star_mender": {"name": "Star Mender", "desc": "Defeat all seven guardians. Unlocks the Starlight scarf."},
	"scholar": {"name": "Scholar", "desc": "Find every journal page. Unlocks the Azure scarf."},
	"treasure": {"name": "Treasure Hunter", "desc": "Open 20 chests. Unlocks the Emerald scarf."},
	"flawless": {"name": "Flawless", "desc": "Defeat a guardian without being hit. Unlocks the Violet scarf."},
	"level10": {"name": "Seasoned", "desc": "Reach level 10."},
	"rich": {"name": "Shard Hoarder", "desc": "Hold 1000 Star Shards."},
	"quests": {"name": "Helping Hand", "desc": "Complete 10 side quests."},
	"ending": {"name": "Dawn Returns", "desc": "Finish the story."},
	"ngp": {"name": "Another Lap", "desc": "Start New Game+."},
	"echo": {"name": "Echo Breaker", "desc": "Defeat an Echo guardian."},
	"daily": {"name": "Trial by Starlight", "desc": "Finish a Daily Trial."},
	"elite": {"name": "Elite Hunter", "desc": "Defeat an elite enemy."},
}


static func stat(name: String) -> int:
	return int(Game.quest_progress.get("stat_" + name, 0))


static func bump(name: String, n: int = 1) -> void:
	Game.quest_progress["stat_" + name] = stat(name) + n


static func has(id: String) -> bool:
	return Game.flag("ach_" + id)


static func count() -> int:
	var n := 0
	for id in LIST:
		if has(id):
			n += 1
	return n


static func unlock(id: String) -> void:
	if not LIST.has(id) or has(id) or Game.trial:
		return
	Game.set_flag("ach_" + id)
	Game.toast.emit("Achievement: %s" % LIST[id]["name"], "good")
	Sfx.play("ability")


static func on_kill(_kind: String) -> void:
	bump("kills")
	check()


static func on_event(id: String) -> void:
	match id:
		"chest": bump("chests")
		"flawless": unlock("flawless")
		"echo": unlock("echo")
		"daily": unlock("daily")
		"elite": unlock("elite")
	check()


static func check() -> void:
	if Game.trial:
		return
	if stat("kills") >= 1: unlock("first_blood")
	if stat("kills") >= 100: unlock("slayer")
	if Game.bosses.size() >= 1: unlock("guardian")
	if Game.bosses.size() >= 7: unlock("star_mender")
	if stat("chests") >= 20: unlock("treasure")
	if Game.level >= 10: unlock("level10")
	if Game.shards >= 1000: unlock("rich")
	if Game.completed: unlock("ending")
	if Game.ngp >= 1: unlock("ngp")
	var pages := 0
	for j in Story.JOURNALS:
		if Game.flag("journal_" + j):
			pages += 1
	if pages >= Story.JOURNALS.size(): unlock("scholar")
	var done := 0
	for q in Game.quests:
		if Game.quests[q] == "claimed":
			done += 1
	if done >= 10: unlock("quests")
