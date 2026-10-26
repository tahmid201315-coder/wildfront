extends RefCounted
## Static crafting helpers. Recipes live in Data.recipes.

static func station_label(station: String) -> String:
	match station:
		"": return "By hand"
		"campfire": return "Campfire"
		"workbench": return "Workbench"
		"cooking": return "Cooking Station"
		"processor": return "Processor"
	return station


static func station_near(station: String) -> bool:
	if station == "":
		return true
	if Game.world and Game.world.has_method("station_near"):
		return Game.world.station_near(station)
	return false


static func is_unlocked(id: String) -> bool:
	return Game.unlocked(String(Data.recipes[id]["unlock"]))


static func craft_time(id: String) -> float:
	var t := float(Data.recipes[id]["time"])
	if Game.has_skill("en2"):
		t *= 0.65
	return t


## Returns "" when the recipe can be crafted right now, otherwise a short reason.
static func blocker(id: String) -> String:
	var r: Dictionary = Data.recipes[id]
	if not is_unlocked(id):
		return "Locked"
	if not station_near(String(r["station"])):
		return "Needs a %s nearby" % station_label(String(r["station"]))
	if not Inv.has_all(r["ing"]):
		return "Missing materials"
	if not Inv.can_craft(r["ing"], String(r["out"]), int(r["qty"])):
		return "Pack is full"
	return ""


static func craft(id: String) -> String:
	var e := blocker(id)
	if e != "":
		return e
	var r: Dictionary = Data.recipes[id]
	for k in r["ing"]:
		Inv.remove(k, int(r["ing"][k]))
	Game.give_item(String(r["out"]), int(r["qty"]))
	Game.add_stat("craft:" + String(r["out"]), int(r["qty"]))
	Game.add_xp(6 + {"starter": 0, "intermediate": 6, "advanced": 14}.get(String(r["tier"]), 0))
	Sfx.play("craft")
	Game.toast("Crafted %s" % Data.item_name(String(r["out"])), "item")
	return ""
