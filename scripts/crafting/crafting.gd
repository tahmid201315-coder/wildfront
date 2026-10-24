extends RefCounted
## Recipe validation and execution. Nothing is consumed unless the whole craft can complete.

const STATION_NAMES := {"": "By hand", "workbench": "Workbench", "campfire": "Campfire"}


## Returns "" when the recipe can be crafted now, otherwise a player-readable reason.
static func block_reason(recipe: Dictionary, station_near: Callable) -> String:
	if Game.level < int(recipe["level"]):
		return "Requires level %d" % int(recipe["level"])
	var st: String = recipe["station"]
	if st != "" and not station_near.call(st):
		return "Stand near a %s" % STATION_NAMES.get(st, st)
	var miss: Dictionary = Inv.missing(recipe["ingredients"])
	if not miss.is_empty():
		var parts: Array = []
		for id in miss:
			parts.append("%d more %s" % [miss[id], Data.item_name(id)])
		return "Need " + ", ".join(parts)
	if not Inv.can_craft(recipe):
		return "Your pack is full"
	return ""


static func craft(recipe_id: String, station_near: Callable) -> Dictionary:
	if not Data.recipes.has(recipe_id):
		return {"ok": false, "reason": "Unknown recipe"}
	var r: Dictionary = Data.recipes[recipe_id]
	var why := block_reason(r, station_near)
	if why != "":
		return {"ok": false, "reason": why}
	# Consume exactly once, then produce. The checks above guarantee both steps succeed.
	for id in r["ingredients"]:
		if not Inv.remove(id, int(r["ingredients"][id])):
			push_error("Crafting inconsistency for %s" % recipe_id)
			return {"ok": false, "reason": "Crafting failed"}
	var left: int = Inv.add(r["result"], int(r["qty"]))
	if left > 0:
		Game.give_item(r["result"], left)
	Game.mark_crafted(r["result"])
	Game.add_xp(int(r["xp"]) if not Game.crafted_once.has("_xp_" + recipe_id) else 0, "craft")
	Game.crafted_once["_xp_" + recipe_id] = true
	Quests.notify_event("craft", r["result"], int(r["qty"]))
	Sfx.play("craft")
	return {"ok": true, "reason": ""}


## Recipes visible in the list for a station: hand recipes plus that station's recipes.
static func visible_recipes(station: String) -> Array:
	var out: Array = []
	for id in Data.recipes:
		var r: Dictionary = Data.recipes[id]
		if r["station"] == "" or r["station"] == station:
			out.append(r)
	out.sort_custom(func(a, b): return int(a["level"]) < int(b["level"]) or (int(a["level"]) == int(b["level"]) and a["name"] < b["name"]))
	return out
