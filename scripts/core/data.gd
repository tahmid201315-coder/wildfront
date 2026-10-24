extends Node
## Static, data-driven game definitions (autoload "Data").
## Add a new species / item / recipe / quest by adding one dictionary entry here.

const SAVE_VERSION := 1
const WORLD_HALF := 120.0
const EMBER_START_X := 50.0
const PACK_SLOTS := 30
const GAME_VERSION := "0.1.0"

var items: Dictionary = {}
var recipes: Dictionary = {}
var creatures: Dictionary = {}
var quests: Dictionary = {}
var quest_order: Array = []
var regions: Dictionary = {}
var landmarks: Dictionary = {}
var lore: Dictionary = {}
var buildings: Dictionary = {}


func _ready() -> void:
	_build_items()
	_build_recipes()
	_build_creatures()
	_build_regions()
	_build_landmarks()
	_build_lore()
	_build_buildings()
	_build_quests()


# ---------------------------------------------------------------- items
func _item(id: String, nm: String, desc: String, kind: String, col: Color, shape: String, stack: int = 99, extra: Dictionary = {}) -> void:
	var d := {"id": id, "name": nm, "desc": desc, "kind": kind, "color": col, "shape": shape, "stack": stack}
	d.merge(extra)
	items[id] = d


func _build_items() -> void:
	_item("wood", "Timber", "Sturdy wood from Aetherwild trees. Used for almost everything.", "resource", Color(0.55, 0.36, 0.2), "log")
	_item("stone", "Stone", "A chunk of weathered rock.", "resource", Color(0.62, 0.64, 0.68), "rock")
	_item("fiber", "Plant Fiber", "Tough strands for rope, cloth and bindings.", "resource", Color(0.6, 0.8, 0.35), "leaf")
	_item("berries", "Sunberries", "Sweet red berries. Restores a little hunger.", "food", Color(0.9, 0.2, 0.3), "berry", 99, {"hunger": 14.0})
	_item("herb", "Meadow Herb", "A soothing herb. Restores a little health.", "food", Color(0.3, 0.75, 0.45), "leaf", 99, {"heal": 12.0})
	_item("ore", "Rust Ore", "Reddish ore found in the Ember Highlands.", "resource", Color(0.75, 0.4, 0.25), "rock")
	_item("crystal", "Aether Crystal", "A faintly humming crystal. Rare.", "resource", Color(0.5, 0.85, 1.0), "gem")
	_item("ember_shard", "Ember Shard", "A warm shard that holds Wildcore energy.", "resource", Color(1.0, 0.55, 0.15), "gem")
	_item("seed_berry", "Sunberry Seed", "Plant it in a farming plot.", "seed", Color(0.85, 0.7, 0.4), "seed", 99, {"crop": "berries"})
	_item("treat", "Friendship Treat", "A crumbly treat that Wildlings love.", "consumable", Color(0.95, 0.75, 0.4), "berry", 50, {"trust": 40.0})
	_item("cooked_berries", "Berry Compote", "Warm, filling and healing.", "food", Color(0.8, 0.25, 0.4), "bowl", 50, {"hunger": 32.0, "heal": 10.0})
	_item("herb_salve", "Herb Salve", "Restores health.", "consumable", Color(0.4, 0.85, 0.6), "bottle", 20, {"heal": 45.0})
	_item("cooling_tonic", "Cooling Tonic", "Protects against heat for a few minutes.", "consumable", Color(0.45, 0.8, 0.95), "bottle", 20, {"heat_resist": 240.0})
	_item("stone_axe", "Stone Axe", "Gather more timber and stone, and strike harder.", "tool", Color(0.7, 0.7, 0.72), "axe", 1)
	_item("kit_foundation", "Foundation Kit", "Place a 4x4 foundation.", "building", Color(0.65, 0.55, 0.4), "box", 20, {"build": "foundation"})
	_item("kit_floor", "Floor Kit", "Place a 4x4 plank floor.", "building", Color(0.7, 0.5, 0.3), "box", 20, {"build": "floor"})
	_item("kit_wall", "Wall Kit", "Place a wall along a foundation edge.", "building", Color(0.72, 0.55, 0.35), "box", 20, {"build": "wall"})
	_item("kit_door", "Door Kit", "Place a door along a foundation edge.", "building", Color(0.6, 0.4, 0.25), "box", 20, {"build": "door"})
	_item("kit_roof", "Roof Kit", "Place a roof over a foundation.", "building", Color(0.75, 0.3, 0.25), "box", 20, {"build": "roof"})
	_item("kit_chest", "Storage Chest Kit", "A chest to store items.", "building", Color(0.65, 0.45, 0.25), "box", 20, {"build": "chest"})
	_item("kit_workbench", "Workbench Kit", "Unlocks building and tool recipes.", "building", Color(0.6, 0.5, 0.35), "box", 20, {"build": "workbench"})
	_item("kit_campfire", "Campfire Kit", "Cook food and rest by the fire.", "building", Color(0.95, 0.5, 0.2), "box", 20, {"build": "campfire"})
	_item("kit_plot", "Farming Plot Kit", "Plant and grow crops.", "building", Color(0.45, 0.32, 0.2), "box", 20, {"build": "plot"})
	_item("kit_lamp", "Lamp Kit", "A decorative lamp that glows at night.", "building", Color(1.0, 0.85, 0.4), "box", 20, {"build": "lamp"})
	_item("kit_rest", "Creature Rest Station Kit", "A cozy spot where a Wildling can work.", "building", Color(0.5, 0.7, 0.6), "box", 20, {"build": "rest"})


# ---------------------------------------------------------------- recipes
func _recipe(id: String, result: String, qty: int, ing: Dictionary, station: String, level: int, xp: int = 10) -> void:
	recipes[id] = {"id": id, "name": items[result]["name"], "result": result, "qty": qty, "ingredients": ing,
		"station": station, "level": level, "duration": 0.0, "xp": xp}


func _build_recipes() -> void:
	_recipe("r_treat", "treat", 2, {"berries": 2, "fiber": 1}, "", 1)
	_recipe("r_seed", "seed_berry", 2, {"berries": 2}, "", 1, 5)
	_recipe("r_axe", "stone_axe", 1, {"wood": 3, "stone": 3, "fiber": 2}, "", 1, 20)
	_recipe("r_campfire", "kit_campfire", 1, {"wood": 6, "stone": 4}, "", 1, 20)
	_recipe("r_workbench", "kit_workbench", 1, {"wood": 10, "stone": 4, "fiber": 3}, "", 1, 30)
	_recipe("r_foundation", "kit_foundation", 1, {"wood": 6, "stone": 3}, "workbench", 1)
	_recipe("r_wall", "kit_wall", 1, {"wood": 3, "fiber": 2}, "workbench", 1)
	_recipe("r_roof", "kit_roof", 1, {"wood": 5, "fiber": 4}, "workbench", 1)
	_recipe("r_cooked", "cooked_berries", 1, {"berries": 3}, "campfire", 1, 8)
	_recipe("r_floor", "kit_floor", 1, {"wood": 3}, "workbench", 2)
	_recipe("r_door", "kit_door", 1, {"wood": 4, "fiber": 2}, "workbench", 2)
	_recipe("r_chest", "kit_chest", 1, {"wood": 8, "fiber": 2}, "workbench", 2)
	_recipe("r_plot", "kit_plot", 1, {"wood": 4, "stone": 2, "fiber": 2}, "workbench", 2, 15)
	_recipe("r_salve", "herb_salve", 1, {"herb": 3, "fiber": 1}, "", 2)
	_recipe("r_lamp", "kit_lamp", 1, {"wood": 2, "stone": 2, "ore": 1}, "workbench", 3)
	_recipe("r_rest", "kit_rest", 1, {"wood": 8, "fiber": 6}, "workbench", 3, 20)
	_recipe("r_tonic", "cooling_tonic", 1, {"herb": 2, "berries": 2}, "campfire", 3)


# ---------------------------------------------------------------- creatures (Wildlings)
func _build_creatures() -> void:
	creatures = {
		"mossbun": {"name": "Mossbun", "desc": "A fluffy, moss-furred hopper that nibbles clover and listens with enormous ears.",
			"region": "meadow", "habitat": "Sunlit Verdant Meadow grass", "rarity": "common", "hp": 30, "speed": 3.2,
			"temperament": "docile", "env": "Open grassland", "difficulty": 40, "food": "berries", "foods": ["berries", "herb"],
			"atk": 3, "ability": "sniff", "ability_name": "Sniff Out",
			"ability_desc": "Reveals nearby resource nodes with glowing markers for 12 seconds.", "cd": 25.0,
			"color": Color(0.55, 0.78, 0.4), "accent": Color(0.95, 0.9, 0.7), "scale": 0.9, "hover": 0.0,
			"work": {"item": "fiber", "interval": 90.0, "cap": 6}, "growth": "Bond grows when fed; levels with the player's gathering."},
		"bramblehog": {"name": "Bramblehog", "desc": "A sturdy, thorn-backed forager. Wary at first, fiercely loyal once it trusts you.",
			"region": "meadow", "habitat": "Forest edges and berry thickets", "rarity": "common", "hp": 60, "speed": 2.6,
			"temperament": "territorial", "env": "Thicket edges", "difficulty": 55, "food": "berries", "foods": ["berries", "cooked_berries"],
			"atk": 6, "ability": "shield", "ability_name": "Thorn Guard",
			"ability_desc": "Halves damage you take for 8 seconds. Passive: +1 yield when gathering timber, stone and fiber.", "cd": 30.0,
			"color": Color(0.5, 0.36, 0.25), "accent": Color(0.35, 0.6, 0.3), "scale": 1.0, "hover": 0.0,
			"work": {"item": "wood", "interval": 120.0, "cap": 6}, "growth": "Levels from encounters."},
		"glimmerwing": {"name": "Glimmerwing", "desc": "A shimmering gliding bird whose wings catch the sun like glass.",
			"region": "meadow", "habitat": "Hilltops and open sky", "rarity": "uncommon", "hp": 28, "speed": 4.2,
			"temperament": "skittish", "env": "High ground", "difficulty": 65, "food": "herb", "foods": ["herb", "berries"],
			"atk": 4, "ability": "updraft", "ability_name": "Updraft",
			"ability_desc": "Launches you high into the air. Passive: hold Jump while falling to glide.", "cd": 12.0,
			"color": Color(0.3, 0.75, 0.8), "accent": Color(1.0, 0.85, 0.4), "scale": 0.9, "hover": 0.9,
			"work": {"item": "fiber", "interval": 150.0, "cap": 4}, "growth": "Levels from exploring."},
		"lumifox": {"name": "Lumifox", "desc": "A slender fox with a tail tipped by soft living light.",
			"region": "meadow", "habitat": "Meadow dusk trails", "rarity": "uncommon", "hp": 34, "speed": 4.0,
			"temperament": "curious", "env": "Open grassland", "difficulty": 60, "food": "cooked_berries", "foods": ["cooked_berries", "berries"],
			"atk": 6, "ability": "glow", "ability_name": "Lantern Tail",
			"ability_desc": "Toggles a warm light around you. Great for nights and caves.", "cd": 2.0,
			"color": Color(0.5, 0.45, 0.85), "accent": Color(1.0, 0.95, 0.6), "scale": 1.0, "hover": 0.0,
			"work": {"item": "herb", "interval": 140.0, "cap": 4}, "growth": "Levels from nights explored."},
		"pondling": {"name": "Pondling", "desc": "A flat-headed amphibian with big, calm eyes. It hums when the water is clean.",
			"region": "meadow", "habitat": "Ponds and river banks", "rarity": "common", "hp": 36, "speed": 2.4,
			"temperament": "docile", "env": "Shallow water", "difficulty": 45, "food": "herb", "foods": ["herb"],
			"atk": 3, "ability": "mist", "ability_name": "Soothing Mist",
			"ability_desc": "Heals you for 25. Passive: wading through water never slows you down.", "cd": 60.0,
			"color": Color(0.3, 0.6, 0.9), "accent": Color(0.95, 0.9, 0.5), "scale": 0.95, "hover": 0.0, "water_ok": true,
			"work": {"item": "herb", "interval": 110.0, "cap": 5}, "growth": "Levels from healing."},
		"snailbell": {"name": "Snailbell", "desc": "A gentle snail whose bell-shaped shell chimes when it tends growing things.",
			"region": "meadow", "habitat": "Damp meadow clearings", "rarity": "common", "hp": 40, "speed": 1.6,
			"temperament": "docile", "env": "Damp grass", "difficulty": 40, "food": "herb", "foods": ["herb", "berries"],
			"atk": 2, "ability": "tend", "ability_name": "Tend Crops",
			"ability_desc": "Waters every farming plot within 14 m and boosts their growth.", "cd": 40.0,
			"color": Color(0.9, 0.7, 0.8), "accent": Color(0.4, 0.7, 0.55), "scale": 0.85, "hover": 0.0,
			"work": {"item": "herb", "interval": 100.0, "cap": 6}, "growth": "Levels from farming."},
		"thistlefinch": {"name": "Thistlefinch", "desc": "A tiny round bird with a thistle-bloom crest, always scouting.",
			"region": "meadow", "habitat": "Tall grass and flower fields", "rarity": "common", "hp": 18, "speed": 4.5,
			"temperament": "skittish", "env": "Flower fields", "difficulty": 50, "food": "berries", "foods": ["berries"],
			"atk": 2, "ability": "scout", "ability_name": "Scout Ahead",
			"ability_desc": "Reveals the map around you in a 40 m radius.", "cd": 30.0,
			"color": Color(0.95, 0.75, 0.3), "accent": Color(0.8, 0.3, 0.55), "scale": 0.7, "hover": 0.7,
			"work": {"item": "berries", "interval": 120.0, "cap": 6}, "growth": "Levels from exploring."},
		"cinderstag": {"name": "Cinderstag", "desc": "A tall, graceful stag whose antlers glow like banked coals.",
			"region": "ember", "habitat": "Ember Highlands ridges", "rarity": "rare", "hp": 80, "speed": 4.8,
			"temperament": "skittish", "env": "Warm rocky hills", "difficulty": 85, "food": "cooked_berries", "foods": ["cooked_berries", "treat"],
			"atk": 9, "ability": "dig", "ability_name": "Ember Dig",
			"ability_desc": "Stamps the ground and unearths buried ore, crystals or shards. Passive: grants heat comfort.", "cd": 45.0,
			"color": Color(0.8, 0.35, 0.25), "accent": Color(1.0, 0.65, 0.2), "scale": 1.15, "hover": 0.0,
			"work": {"item": "ore", "interval": 150.0, "cap": 4}, "growth": "Levels from digging."},
		"rustmaw": {"name": "Rustmaw", "desc": "A hulking, plated beast that guards Rustmaw Hollow. It telegraphs every attack.",
			"region": "ember", "habitat": "Rustmaw Hollow", "rarity": "rare", "hp": 140, "speed": 3.6,
			"temperament": "hostile", "env": "Hollow", "difficulty": 999, "food": "", "foods": [], "atk": 16, "hostile": true,
			"ability": "", "ability_name": "", "ability_desc": "", "cd": 0.0,
			"color": Color(0.55, 0.3, 0.22), "accent": Color(0.95, 0.5, 0.2), "scale": 1.7, "hover": 0.0, "work": {}, "growth": ""},
	}


func tameable_ids() -> Array:
	var out: Array = []
	for k in creatures:
		if not creatures[k].get("hostile", false):
			out.append(k)
	return out


# ---------------------------------------------------------------- regions / landmarks / lore
func _build_regions() -> void:
	regions = {
		"meadow": {"name": "Verdant Meadow", "desc": "Rolling green hills, gentle rivers and wooden ruins.", "color": Color(0.35, 0.7, 0.35), "xp": 25},
		"ember": {"name": "Ember Highlands", "desc": "Warm, rocky hills veined with glowing minerals.", "color": Color(0.85, 0.4, 0.2), "xp": 60},
	}
	# Moonmist Forest and Frostveil Mountains are planned but NOT in this build.


func region_at(x: float, _z: float) -> String:
	return "ember" if x >= EMBER_START_X else "meadow"


func _build_landmarks() -> void:
	landmarks = {
		"camp": {"name": "Starter Camp", "pos": Vector2(0, 0), "region": "meadow", "lore": "field_notes", "xp": 0},
		"old_marker": {"name": "Old Wooden Marker", "pos": Vector2(24, -20), "region": "meadow", "lore": "marker", "xp": 30},
		"watchtower": {"name": "Collapsed Watchtower", "pos": Vector2(-32, 30), "region": "meadow", "lore": "watchtower", "xp": 30},
		"ember_gate": {"name": "Ember Gate", "pos": Vector2(56, 4), "region": "ember", "lore": "ember_gate", "xp": 40},
		"hollow": {"name": "Rustmaw Hollow", "pos": Vector2(78, 34), "region": "ember", "lore": "hollow", "xp": 40},
		"shrine": {"name": "Wildcore Shrine", "pos": Vector2(86, -18), "region": "ember", "lore": "shrine", "xp": 50},
	}


func _build_lore() -> void:
	lore = {
		"field_notes": {"title": "Explorer's Notes", "text": "You arrive in Aetherwild with a pack, a notebook and more questions than answers. Gather supplies, befriend the Wildlings and build a camp. The ancient Wildcores will wait."},
		"marker": {"title": "The Old Marker", "text": "A weathered post carved with a spiral and four dots. Travelers once marked the four regions this way: meadow, ember, mist and frost. Only the first two are still open."},
		"watchtower": {"title": "Collapsed Watchtower", "text": "The tower's logbook: 'The Wildcore hum has changed pitch three nights running. The creatures are moving east. We are leaving at dawn.'"},
		"ember_gate": {"title": "The Ember Gate", "text": "Two blackened pillars frame the pass. Scorch marks spiral outward, as if something pulsed with great force from the hills beyond."},
		"hollow": {"title": "Rustmaw Hollow", "text": "Claw marks and plates of shed armor litter the floor. The Rustmaw was not always aggressive. The disturbance has made it afraid of everything."},
		"shrine": {"title": "Wildcore Shrine", "text": "A cracked stone basin sits above a dark socket. Ember Shards fit its grooves exactly. When three are placed, the shrine hums and the ground feels warmer."},
		"core_restored": {"title": "A Core Awakens", "text": "The shrine's light flows outward in rings. One Wildcore is awake again, and somewhere far off, something answers."},
	}


# ---------------------------------------------------------------- buildings
func _build_buildings() -> void:
	buildings = {
		"foundation": {"name": "Foundation", "size": Vector2(4, 4), "kind": "grid", "radius": 2.8},
		"floor": {"name": "Floor", "size": Vector2(4, 4), "kind": "grid", "radius": 2.8},
		"wall": {"name": "Wall", "size": Vector2(4, 0.3), "kind": "edge", "radius": 0.0},
		"door": {"name": "Door", "size": Vector2(4, 0.3), "kind": "edge", "radius": 0.0},
		"roof": {"name": "Roof", "size": Vector2(4.6, 4.6), "kind": "roof", "radius": 0.0},
		"chest": {"name": "Storage Chest", "size": Vector2(1.2, 0.8), "kind": "free", "radius": 0.9},
		"workbench": {"name": "Workbench", "size": Vector2(2.0, 1.0), "kind": "free", "radius": 1.3},
		"campfire": {"name": "Campfire", "size": Vector2(1.4, 1.4), "kind": "free", "radius": 1.0},
		"plot": {"name": "Farming Plot", "size": Vector2(2.4, 2.4), "kind": "free", "radius": 1.5},
		"lamp": {"name": "Decorative Lamp", "size": Vector2(0.5, 0.5), "kind": "free", "radius": 0.5},
		"rest": {"name": "Creature Rest Station", "size": Vector2(2.0, 2.0), "kind": "free", "radius": 1.4},
	}


# ---------------------------------------------------------------- quests
func _quest(id: String, nm: String, cat: String, desc: String, objs: Array, reward: Dictionary, requires: Array = [], level: int = 1, hint: String = "", marker: String = "") -> void:
	quests[id] = {"id": id, "name": nm, "cat": cat, "desc": desc, "objectives": objs, "reward": reward,
		"requires": requires, "level": level, "hint": hint, "marker": marker}
	quest_order.append(id)


func _o(type: String, target: String, count: float, text: String) -> Dictionary:
	return {"type": type, "target": target, "count": count, "text": text}


func _build_quests() -> void:
	_quest("q_move", "First Steps", "Tutorial", "Get your bearings in Aetherwild.",
		[_o("walk", "", 20, "Walk around"), _o("look", "", 6, "Turn the camera")], {"xp": 30, "items": {"berries": 2}}, [], 1,
		"Drag the left side of the screen to move. Drag the right side to look around.")
	_quest("q_wood", "Timber!", "Tutorial", "Collect timber from nearby trees.",
		[_o("gather", "wood", 6, "Gather timber")], {"xp": 40}, ["q_move"], 1,
		"Walk up to a tree and press the action button to gather.")
	_quest("q_food", "Something to Eat", "Collection", "Pick berries from the bushes.",
		[_o("gather", "berries", 4, "Pick Sunberries")], {"xp": 40}, ["q_wood"], 1,
		"Red berry bushes grow around camp. Eat berries from your Pack when hungry.")
	_quest("q_pack", "Check Your Pack", "Tutorial", "Open your inventory.",
		[_o("open_inventory", "", 1, "Open the Pack")], {"xp": 20}, ["q_food"], 1,
		"Tap the Pack button at the top right.")
	_quest("q_meet", "Rustling in the Grass", "Creature bonding", "Find your first Wildling.",
		[_o("discover", "", 1, "Discover a Wildling")], {"xp": 40, "items": {"treat": 2}}, ["q_pack"], 1,
		"Something fluffy lives just east of camp. Follow the quest marker on the compass.", "starter_mossbun")
	_quest("q_bond", "A New Friend", "Creature bonding", "Befriend a Wildling.",
		[_o("befriend", "", 1, "Befriend a Wildling")], {"xp": 80}, ["q_meet"], 1,
		"Approach slowly, then offer food or a Friendship Treat with the action button.", "starter_mossbun")
	_quest("q_bench", "A Place to Work", "Crafting", "Craft a workbench.",
		[_o("gather", "stone", 4, "Gather stone"), _o("gather", "fiber", 4, "Gather fiber"), _o("craft", "kit_workbench", 1, "Craft a Workbench Kit")],
		{"xp": 60}, ["q_bond"], 1, "Open Pack, then the Craft tab. Rocks give stone; green bushes give fiber.")
	_quest("q_place", "Set Up Shop", "Construction", "Place your workbench.",
		[_o("place", "workbench", 1, "Place the Workbench")], {"xp": 40}, ["q_bench"], 1,
		"Press Build, pick the Workbench Kit, then Place.")
	_quest("q_shelter", "Four Walls", "Construction", "Build a shelter: a foundation, three walls and a roof.",
		[_o("build_shelter", "", 1, "Build a shelter")], {"xp": 120, "items": {"herb": 3}}, ["q_place"], 1,
		"Craft Foundation, Wall and Roof kits at the workbench. Walls snap to foundation edges.")
	_quest("q_save", "Remember This Moment", "Tutorial", "Save your progress.",
		[_o("save", "", 1, "Save the game from the Pause menu")], {"xp": 30}, ["q_shelter"], 1,
		"Open the Pause menu and press Save.")
	_quest("q_marker", "The Old Marker", "Exploration", "Visit the old wooden marker northeast of camp.",
		[_o("landmark", "old_marker", 1, "Visit the Old Marker")], {"xp": 40}, ["q_save"], 1, "", "old_marker")
	_quest("q_friends", "Wildling Friends", "Creature bonding", "Befriend three Wildlings in total.",
		[_o("befriend", "", 3, "Befriend Wildlings")], {"xp": 100, "items": {"treat": 3}}, ["q_bond"], 2)
	_quest("q_pair", "Bonded Pair", "Creature bonding", "Use your companion's ability three times.",
		[_o("ability", "", 3, "Use companion abilities")], {"xp": 60}, ["q_bond"], 2,
		"Set an active companion in the Journal, then press its ability button.")
	_quest("q_farm", "Green Thumb", "Farming", "Plant, water and harvest a crop.",
		[_o("craft", "kit_plot", 1, "Craft a Farming Plot Kit"), _o("place", "plot", 1, "Place the plot"), _o("harvest", "", 1, "Harvest a crop")],
		{"xp": 100, "items": {"seed_berry": 2}}, ["q_shelter"], 2, "Plant a Sunberry Seed, water the plot, wait for it to grow.")
	_quest("q_ember", "Beyond the Meadow", "Regional discovery", "Travel east into the Ember Highlands.",
		[_o("region", "ember", 1, "Enter the Ember Highlands")], {"xp": 80}, ["q_save"], 2, "", "ember_gate")
	_quest("q_hollow", "Rustmaw Hollow", "Boss challenge", "Defeat the Rustmaw guarding the hollow.",
		[_o("defeat", "rustmaw", 1, "Defeat the Rustmaw")], {"xp": 200, "items": {"crystal": 2}}, ["q_ember"], 3,
		"Watch for red warning circles on the ground and move out of them. Your companion helps.", "hollow")
	_quest("q_core", "Restore the Wildcore", "Exploration", "Gather three Ember Shards and place them in the Wildcore Shrine.",
		[_o("gather", "ember_shard", 3, "Collect Ember Shards"), _o("restore_core", "", 1, "Restore the Wildcore Shrine")],
		{"xp": 250}, ["q_ember"], 3, "Ember shards glow orange in the Highlands.", "shrine")


func get_item(id: String) -> Dictionary:
	return items.get(id, {})


func item_name(id: String) -> String:
	return str(items.get(id, {}).get("name", id))


## Returns a list of human-readable problems with the data tables (empty = OK).
func validate() -> Array:
	var errs: Array = []
	for rid in recipes:
		var r: Dictionary = recipes[rid]
		if not items.has(r["result"]):
			errs.append("recipe %s: unknown result %s" % [rid, r["result"]])
		for ing in r["ingredients"]:
			if not items.has(ing):
				errs.append("recipe %s: unknown ingredient %s" % [rid, ing])
	for cid in creatures:
		var c: Dictionary = creatures[cid]
		for f in c["foods"]:
			if not items.has(f):
				errs.append("creature %s: unknown food %s" % [cid, f])
		if c.get("work", {}).has("item") and not items.has(c["work"]["item"]):
			errs.append("creature %s: unknown work item" % cid)
	for qid in quests:
		var q: Dictionary = quests[qid]
		for req in q["requires"]:
			if not quests.has(req):
				errs.append("quest %s: unknown prerequisite %s" % [qid, req])
		for it in q["reward"].get("items", {}):
			if not items.has(it):
				errs.append("quest %s: unknown reward item %s" % [qid, it])
	for lid in landmarks:
		if not lore.has(landmarks[lid]["lore"]):
			errs.append("landmark %s: unknown lore %s" % [lid, landmarks[lid]["lore"]])
	for iid in items:
		var b: String = items[iid].get("build", "")
		if b != "" and not buildings.has(b):
			errs.append("item %s: unknown building %s" % [iid, b])
	return errs
