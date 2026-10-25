extends RefCounted
## Recipes and buildable structures.
## Recipe station: "" (by hand), "campfire", "workbench", "cooking", "processor".
## unlock: "" (always) or a token granted by quests / discoveries / skills / levels.

static func _r(out: String, qty: int, ing: Dictionary, station: String, unlock: String, time: float, tier: String = "starter") -> Dictionary:
	return {"out": out, "qty": qty, "ing": ing, "station": station, "unlock": unlock, "time": time, "tier": tier}


static func recipes() -> Dictionary:
	var r := {}
	# starter
	r["stone_axe"] = _r("stone_axe", 1, {"wood": 2, "stone": 2, "fiber": 2}, "", "", 2.0)
	r["stone_pickaxe"] = _r("stone_pickaxe", 1, {"wood": 2, "stone": 3, "fiber": 2}, "", "", 2.0)
	r["wooden_spear"] = _r("wooden_spear", 1, {"wood": 3, "stone": 1, "fiber": 2}, "", "", 2.0)
	r["bandage"] = _r("bandage", 1, {"fiber": 3, "herb": 1}, "", "", 1.5)
	r["stone_blade"] = _r("stone_blade", 1, {"wood": 2, "stone": 4, "fiber": 3}, "", "log_coast", 3.0)
	# campfire cooking and smelting
	r["cooked_meat"] = _r("cooked_meat", 1, {"raw_meat": 1}, "campfire", "", 2.0)
	r["iron_ingot"] = _r("iron_ingot", 1, {"iron_ore": 2, "wood": 1}, "campfire", "", 3.0, "intermediate")
	r["copper_ingot"] = _r("copper_ingot", 1, {"copper_ore": 2, "wood": 1}, "campfire", "", 3.0, "intermediate")
	# cooking station
	r["stew"] = _r("stew", 1, {"mushroom": 2, "berries": 2, "raw_meat": 1}, "cooking", "", 3.5, "intermediate")
	r["herb_tonic"] = _r("herb_tonic", 1, {"herb": 3, "berries": 1}, "cooking", "", 3.0, "intermediate")
	r["heat_tonic"] = _r("heat_tonic", 1, {"herb": 2, "ember_core": 1, "berries": 2}, "cooking", "boss_grove", 4.0, "advanced")
	# workbench intermediate
	r["iron_axe"] = _r("iron_axe", 1, {"wood": 3, "iron_ingot": 3, "fiber": 2}, "workbench", "workbench", 4.0, "intermediate")
	r["iron_pickaxe"] = _r("iron_pickaxe", 1, {"wood": 3, "iron_ingot": 3, "fiber": 2}, "workbench", "workbench", 4.0, "intermediate")
	r["reinforced_blade"] = _r("reinforced_blade", 1, {"wood": 2, "iron_ingot": 4, "hide": 1, "fiber": 2}, "workbench", "workbench", 5.0, "intermediate")
	r["hide_armor"] = _r("hide_armor", 1, {"hide": 6, "fiber": 6, "fang": 2}, "workbench", "workbench", 5.0, "intermediate")
	r["backpack_2"] = _r("backpack_2", 1, {"hide": 4, "fiber": 8, "iron_ingot": 1}, "workbench", "survey_kit", 4.0, "intermediate")
	r["iron_armor"] = _r("iron_armor", 1, {"iron_ingot": 8, "hide": 3, "fiber": 4}, "workbench", "facility", 6.0, "intermediate")
	r["repair_kit"] = _r("repair_kit", 1, {"iron_ingot": 1, "fiber": 2, "wood": 1}, "workbench", "workbench", 2.5, "intermediate")
	r["medkit"] = _r("medkit", 1, {"bandage": 2, "herb_tonic": 1, "fiber": 2}, "workbench", "facility", 4.0, "intermediate")
	# advanced
	r["heat_suit"] = _r("heat_suit", 1, {"iron_ingot": 5, "copper_ingot": 3, "hide": 4, "machine_part": 3, "crystal": 2}, "workbench", "facility", 8.0, "advanced")
	r["energy_blade"] = _r("energy_blade", 1, {"crystal": 4, "iron_ingot": 3, "copper_ingot": 3, "machine_part": 2}, "workbench", "skill_adv", 8.0, "advanced")
	r["crystal_pickaxe"] = _r("crystal_pickaxe", 1, {"crystal": 3, "iron_ingot": 3, "copper_ingot": 1, "wood": 2}, "workbench", "skill_adv", 7.0, "advanced")
	r["crystal_axe"] = _r("crystal_axe", 1, {"crystal": 3, "iron_ingot": 3, "copper_ingot": 1, "wood": 2}, "workbench", "skill_adv", 7.0, "advanced")
	r["crystal_armor"] = _r("crystal_armor", 1, {"crystal": 5, "iron_ingot": 6, "hide": 4, "machine_part": 3}, "workbench", "skill_adv", 10.0, "advanced")
	r["crystal_cannon"] = _r("crystal_cannon", 1, {"crystal": 6, "iron_ingot": 5, "copper_ingot": 4, "machine_part": 4}, "workbench", "boss_furnace", 10.0, "advanced")
	r["backpack_3"] = _r("backpack_3", 1, {"hide": 8, "fiber": 12, "iron_ingot": 3, "copper_ingot": 2}, "workbench", "boss_furnace", 7.0, "advanced")
	return r


## Buildable structures. kind decides snapping and behaviour. size = footprint (x,z) in metres.
static func _s(name: String, kind: String, cost: Dictionary, size: Vector2, unlock: String, desc: String, tier: String = "starter") -> Dictionary:
	return {"name": name, "kind": kind, "cost": cost, "size": size, "unlock": unlock, "desc": desc, "tier": tier}


static func structures() -> Dictionary:
	var s := {}
	s["campfire"] = _s("Campfire", "free", {"wood": 5, "stone": 3}, Vector2(1.2, 1.2), "", "Cook, smelt, stay warm and set your respawn point.")
	s["chest"] = _s("Wooden Storage Box", "free", {"wood": 8}, Vector2(1.2, 0.8), "", "Stores up to 24 stacks of items.")
	s["shelter"] = _s("Simple Shelter", "free", {"wood": 14, "fiber": 8}, Vector2(4.0, 4.0), "", "A quick lean-to. Keeps off the weather and counts as shelter.")
	s["bedroll"] = _s("Bedroll", "free", {"fiber": 6, "hide": 1}, Vector2(1.0, 2.0), "", "Sleep to skip the night and set your respawn point.")
	s["foundation"] = _s("Foundation", "foundation", {"wood": 6, "stone": 2}, Vector2(4.0, 4.0), "", "A levelled 4x4 m base. Snaps to a grid.")
	s["floor"] = _s("Floor", "foundation", {"wood": 4}, Vector2(4.0, 4.0), "", "Raised wooden floor. Snaps to a grid.")
	s["wall"] = _s("Wall", "edge", {"wood": 4}, Vector2(4.0, 0.3), "", "Wall piece. Snaps to foundation edges.")
	s["door"] = _s("Door", "edge", {"wood": 5, "fiber": 2}, Vector2(4.0, 0.3), "", "Doorway with a working door.")
	s["roof"] = _s("Roof", "roof", {"wood": 6, "fiber": 2}, Vector2(4.4, 4.4), "", "Roof panel. Snaps over a foundation.")
	s["workbench"] = _s("Workbench", "free", {"wood": 10, "stone": 6, "fiber": 4}, Vector2(2.2, 1.0), "log_coast", "Craft tools, weapons and armour.", "intermediate")
	s["cooking"] = _s("Cooking Station", "free", {"wood": 8, "stone": 8, "iron_ingot": 1}, Vector2(2.0, 1.2), "workbench", "Prepare stews and tonics.", "intermediate")
	s["lamp"] = _s("Lantern Post", "free", {"wood": 2, "crystal": 1}, Vector2(0.6, 0.6), "workbench", "A crystal lantern. Lights up the night.", "intermediate")
	s["barricade"] = _s("Spike Barricade", "free", {"wood": 6, "stone": 2}, Vector2(2.4, 0.8), "workbench", "Wounds creatures that touch it.", "intermediate")
	s["reinforced_wall"] = _s("Reinforced Wall", "edge", {"wood": 4, "stone": 4, "iron_ingot": 2}, Vector2(4.0, 0.4), "workbench", "A sturdy wall that enemies cannot break.", "intermediate")
	s["turret"] = _s("Crystal Turret", "free", {"iron_ingot": 4, "copper_ingot": 2, "machine_part": 2, "crystal": 2}, Vector2(1.0, 1.0), "facility", "Automatically shoots hostile creatures.", "advanced")
	s["processor"] = _s("Resource Processor", "free", {"iron_ingot": 5, "copper_ingot": 3, "machine_part": 3, "crystal": 2}, Vector2(2.0, 2.0), "facility", "Smelts ore into ingots on its own while you explore.", "advanced")
	return s
