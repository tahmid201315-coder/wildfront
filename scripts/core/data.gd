extends Node
## Autoload "Data": all static game definitions, merged from the data_* modules.

const DW = preload("res://scripts/core/data_world.gd")
const DI = preload("res://scripts/core/data_items.gd")
const DC = preload("res://scripts/core/data_craft.gd")
const DCR = preload("res://scripts/core/data_creatures.gd")
const DS = preload("res://scripts/core/data_story.gd")

const GAME_VERSION := "0.1.0"
const SAVE_VERSION := 1

var items: Dictionary
var recipes: Dictionary
var structures: Dictionary
var resources: Dictionary
var animals: Dictionary
var enemies: Dictionary
var bosses: Dictionary
var loot_tables: Dictionary
var skills: Dictionary
var logs: Dictionary
var quests: Dictionary
var quest_order: Array
var dialogues: Dictionary
var regions: Dictionary = DW.REGIONS
var sites: Dictionary = DW.SITES


func _init() -> void:
	items = DI.build()
	recipes = DC.recipes()
	structures = DC.structures()
	resources = DCR.resources()
	animals = DCR.animals()
	enemies = DCR.enemies()
	bosses = DCR.bosses()
	loot_tables = DCR.loot_tables()
	skills = DCR.skills()
	logs = DS.logs()
	quests = DS.quests()
	quest_order = DS.quest_order()
	dialogues = DS.dialogues()


func item(id: String) -> Dictionary:
	return items.get(id, {})


func item_name(id: String) -> String:
	return items[id]["name"] if items.has(id) else id


func stack_limit(id: String) -> int:
	return int(items[id]["stack"]) if items.has(id) else 1


## Returns a list of human-readable consistency errors (empty when the data is sound).
func validate() -> Array:
	var errs: Array = []
	for rid in recipes:
		var r: Dictionary = recipes[rid]
		if not items.has(r["out"]):
			errs.append("recipe %s: unknown output %s" % [rid, r["out"]])
		for ing in r["ing"]:
			if not items.has(ing):
				errs.append("recipe %s: unknown ingredient %s" % [rid, ing])
	for sid in structures:
		for ing in structures[sid]["cost"]:
			if not items.has(ing):
				errs.append("structure %s: unknown cost item %s" % [sid, ing])
	for rid in resources:
		for d in resources[rid]["drops"]:
			if not items.has(d[0]):
				errs.append("resource %s: unknown drop %s" % [rid, d[0]])
	for tid in loot_tables:
		for e in loot_tables[tid]:
			if not items.has(e[0]):
				errs.append("loot %s: unknown item %s" % [tid, e[0]])
	for eid in enemies:
		for d in enemies[eid]["drops"]:
			if not items.has(d[0]):
				errs.append("enemy %s: unknown drop %s" % [eid, d[0]])
	for bid in bosses:
		for d in bosses[bid]["drops"]:
			if not items.has(d[0]):
				errs.append("boss %s: unknown drop %s" % [bid, d[0]])
		if not sites.has(bosses[bid]["site"]):
			errs.append("boss %s: unknown site" % bid)
	for qid in quests:
		for req in quests[qid]["requires"]:
			if not quests.has(req):
				errs.append("quest %s: unknown requirement %s" % [qid, req])
		for rw in quests[qid]["reward"].get("items", {}):
			if not items.has(rw):
				errs.append("quest %s: unknown reward %s" % [qid, rw])
	for sid in skills:
		var rq: String = skills[sid]["req"]
		if rq != "" and not skills.has(rq):
			errs.append("skill %s: unknown requirement" % sid)
	for q in quest_order:
		if not quests.has(q):
			errs.append("quest_order lists unknown quest %s" % q)
	return errs
