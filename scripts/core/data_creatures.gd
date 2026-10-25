extends RefCounted
## Harvestable resources, wildlife, enemies, bosses, loot tables and skills.

static func resources() -> Dictionary:
	var r := {}
	# id: model kind, hits (health), tool ("" = hands), tier required, drops, respawn seconds, size (collision radius), sound
	r["pebbles"] = {"name": "Loose Stones", "model": "rock", "scale": 0.45, "hits": 1, "tool": "", "tier": 0, "drops": [["stone", 1, 2]], "respawn": 240.0, "radius": 0.5}
	r["branches"] = {"name": "Fallen Branches", "model": "log", "scale": 0.7, "hits": 1, "tool": "", "tier": 0, "drops": [["wood", 1, 2]], "respawn": 240.0, "radius": 0.6}
	r["palm"] = {"name": "Palm Tree", "model": "palm", "scale": 1.0, "hits": 5, "tool": "axe", "tier": 0, "drops": [["wood", 3, 4], ["coconut", 0, 2]], "respawn": 600.0, "radius": 0.5, "tree": true}
	r["broadleaf"] = {"name": "Oak Tree", "model": "broadleaf", "scale": 1.0, "hits": 6, "tool": "axe", "tier": 0, "drops": [["wood", 4, 6], ["fiber", 0, 1]], "respawn": 700.0, "radius": 0.6, "tree": true}
	r["pine"] = {"name": "Pine Tree", "model": "pine", "scale": 1.0, "hits": 7, "tool": "axe", "tier": 0, "drops": [["wood", 5, 7]], "respawn": 700.0, "radius": 0.55, "tree": true}
	r["dead_tree"] = {"name": "Dead Tree", "model": "dead_tree", "scale": 1.0, "hits": 3, "tool": "axe", "tier": 0, "drops": [["wood", 2, 3]], "respawn": 500.0, "radius": 0.4, "tree": true}
	r["burnt_tree"] = {"name": "Charred Tree", "model": "burnt_tree", "scale": 1.0, "hits": 3, "tool": "axe", "tier": 0, "drops": [["wood", 2, 3]], "respawn": 500.0, "radius": 0.4, "tree": true}
	r["rock"] = {"name": "Boulder", "model": "rock_big", "scale": 0.5, "hits": 5, "tool": "pick", "tier": 1, "drops": [["stone", 3, 5]], "respawn": 600.0, "radius": 1.2}
	r["iron"] = {"name": "Iron Deposit", "model": "iron_ore", "scale": 1.0, "hits": 7, "tool": "pick", "tier": 1, "drops": [["iron_ore", 2, 4], ["stone", 0, 2]], "respawn": 900.0, "radius": 1.0}
	r["copper"] = {"name": "Copper Deposit", "model": "copper_ore", "scale": 1.0, "hits": 7, "tool": "pick", "tier": 1, "drops": [["copper_ore", 2, 4], ["stone", 0, 2]], "respawn": 900.0, "radius": 1.0}
	r["crystal"] = {"name": "Energy Crystal", "model": "crystal", "scale": 1.2, "hits": 8, "tool": "pick", "tier": 2, "drops": [["crystal", 1, 2]], "respawn": 1200.0, "radius": 0.7, "glow": true}
	r["ember"] = {"name": "Ember Crystal", "model": "crystal_red", "scale": 1.2, "hits": 8, "tool": "pick", "tier": 2, "drops": [["ember_core", 1, 2], ["crystal", 0, 1]], "respawn": 1200.0, "radius": 0.7, "glow": true}
	r["scrap"] = {"name": "Machine Wreckage", "model": "wreck_part", "scale": 1.6, "hits": 5, "tool": "pick", "tier": 1, "drops": [["machine_part", 1, 2], ["iron_ore", 0, 2]], "respawn": 1500.0, "radius": 0.9}
	r["berry_bush"] = {"name": "Sunberry Bush", "model": "bush", "variant": 1, "scale": 0.8, "hits": 1, "tool": "", "tier": 0, "drops": [["berries", 3, 5]], "respawn": 300.0, "radius": 0.6}
	r["herb_plant"] = {"name": "Medicinal Herb", "model": "flower", "scale": 1.3, "hits": 1, "tool": "", "tier": 0, "drops": [["herb", 1, 3]], "respawn": 420.0, "radius": 0.4}
	r["fiber_plant"] = {"name": "Fibrous Grass", "model": "fern", "scale": 0.8, "hits": 1, "tool": "", "tier": 0, "drops": [["fiber", 2, 4]], "respawn": 260.0, "radius": 0.5}
	r["mushrooms"] = {"name": "Glowcap Cluster", "model": "mushroom", "scale": 1.2, "hits": 1, "tool": "", "tier": 0, "drops": [["mushroom", 2, 4]], "respawn": 400.0, "radius": 0.5}
	return r


static func animals() -> Dictionary:
	var a := {}
	a["crab"] = {"name": "Shore Crab", "hp": 14.0, "speed": 3.5, "flee": 8.0, "drops": [["raw_meat", 1, 1]], "xp": 4, "regions": ["coast"], "size": 0.5}
	a["mossdeer"] = {"name": "Mossdeer", "hp": 40.0, "speed": 8.0, "flee": 16.0, "drops": [["raw_meat", 2, 3], ["hide", 1, 2]], "xp": 10, "regions": ["forest", "coast"], "size": 1.0}
	a["ridge_goat"] = {"name": "Ridge Goat", "hp": 55.0, "speed": 7.0, "flee": 14.0, "drops": [["raw_meat", 2, 3], ["hide", 1, 2]], "xp": 14, "regions": ["highlands"], "size": 1.0}
	a["ember_newt"] = {"name": "Ember Newt", "hp": 30.0, "speed": 5.0, "flee": 10.0, "drops": [["raw_meat", 1, 2], ["hide", 0, 1]], "xp": 14, "regions": ["ashen"], "size": 0.7}
	return a


## Hostile enemies. 'ai' selects the behaviour script branch.
static func enemies() -> Dictionary:
	var e := {}
	e["stalker"] = {"name": "Forest Stalker", "hp": 70.0, "speed": 7.8, "dmg": 11.0, "detect": 24.0, "leash": 45.0, "armor": 0.0, "xp": 28,
		"drops": [["hide", 1, 2], ["fang", 1, 2], ["raw_meat", 1, 2]], "ai": "melee_fast", "range": 1.9, "windup": 0.35, "cooldown": 1.1,
		"regions": ["forest", "coast"], "size": 1.0}
	e["brute"] = {"name": "Rockback Brute", "hp": 260.0, "speed": 2.9, "dmg": 32.0, "detect": 16.0, "leash": 30.0, "armor": 0.35, "xp": 70,
		"drops": [["stone", 3, 5], ["iron_ore", 1, 3], ["hide", 2, 3]], "ai": "melee_heavy", "range": 3.2, "windup": 1.15, "cooldown": 2.6,
		"regions": ["highlands", "forest"], "size": 1.5}
	e["wraith"] = {"name": "Crystal Wraith", "hp": 75.0, "speed": 5.0, "dmg": 15.0, "detect": 30.0, "leash": 50.0, "armor": 0.0, "xp": 55,
		"drops": [["crystal", 0, 1], ["machine_part", 0, 1], ["ember_core", 0, 1]], "ai": "ranged", "range": 22.0, "windup": 0.8, "cooldown": 2.2,
		"regions": ["highlands", "ashen", "core"], "size": 1.1}
	e["sentinel"] = {"name": "Ruin Sentinel", "hp": 180.0, "speed": 3.8, "dmg": 20.0, "detect": 26.0, "leash": 40.0, "armor": 0.2, "xp": 85,
		"drops": [["machine_part", 1, 2], ["copper_ore", 1, 3], ["iron_ore", 1, 2]], "ai": "sentinel", "range": 3.0, "windup": 0.9, "cooldown": 1.8,
		"regions": ["highlands", "ashen", "core"], "size": 1.3}
	return e


static func bosses() -> Dictionary:
	var b := {}
	b["grove_guardian"] = {"name": "The Grove Guardian", "hp": 1100.0, "xp": 400, "site": "grove", "unlock": "boss_grove",
		"drops": [["thorn_edge", 1, 1], ["verdant_seal", 1, 1], ["crystal", 2, 3], ["hide", 4, 6]], "title": "A colossus of root and bark"}
	b["furnace_colossus"] = {"name": "The Furnace Colossus", "hp": 2400.0, "xp": 900, "site": "furnace", "unlock": "boss_furnace",
		"drops": [["magma_blade", 1, 1], ["core_key", 1, 1], ["ember_core", 3, 4], ["machine_part", 4, 5]], "title": "A foundry automaton running far too hot"}
	b["core_architect"] = {"name": "The Core Architect", "hp": 3600.0, "xp": 2000, "site": "core_hub", "unlock": "boss_architect",
		"drops": [["crystal", 6, 8], ["machine_part", 6, 8]], "title": "The mind that tried to hold the island still"}
	return b


## Loot tables for containers: [item, min, max, chance]
static func loot_tables() -> Dictionary:
	var t := {}
	t["supply"] = [["berries", 2, 4, 0.8], ["fiber", 2, 4, 0.7], ["wood", 2, 5, 0.6], ["bandage", 1, 1, 0.45], ["ration", 1, 1, 0.3], ["stone", 2, 4, 0.5]]
	t["locker"] = [["bandage", 1, 2, 0.8], ["machine_part", 1, 2, 0.6], ["copper_ingot", 1, 2, 0.5], ["ration", 1, 2, 0.6], ["herb_tonic", 1, 1, 0.35]]
	t["cache"] = [["iron_ingot", 2, 4, 0.9], ["crystal", 1, 2, 0.7], ["machine_part", 1, 3, 0.7], ["medkit", 1, 1, 0.45], ["repair_kit", 1, 1, 0.5]]
	t["boss_chest"] = [["crystal", 2, 4, 1.0], ["machine_part", 3, 5, 1.0], ["medkit", 1, 2, 1.0]]
	t["treasure"] = [["crystal", 2, 3, 0.9], ["iron_ingot", 3, 5, 0.8], ["copper_ingot", 2, 4, 0.8], ["medkit", 1, 1, 0.6]]
	return t


## Skill tree: id -> branch, name, desc, requires (id or ""), cost
static func skills() -> Dictionary:
	var s := {}
	s["sv1"] = {"branch": "survival", "name": "Forager", "desc": "+25% resources from gathering.", "req": "", "cost": 1}
	s["sv2"] = {"branch": "survival", "name": "Lean Rations", "desc": "Hunger drains 25% slower.", "req": "sv1", "cost": 1}
	s["sv3"] = {"branch": "survival", "name": "Second Wind", "desc": "Stamina regenerates 30% faster.", "req": "sv2", "cost": 1}
	s["sv4"] = {"branch": "survival", "name": "Thick Skin", "desc": "Take 25% less heat and cold damage.", "req": "sv3", "cost": 1}
	s["sv5"] = {"branch": "survival", "name": "Hearty Meals", "desc": "Food and medicine restore 25% more.", "req": "sv4", "cost": 2}
	s["cb1"] = {"branch": "combat", "name": "Weapon Mastery", "desc": "+15% weapon damage.", "req": "", "cost": 1}
	s["cb2"] = {"branch": "combat", "name": "Nimble", "desc": "Dodging costs less stamina and recovers faster.", "req": "cb1", "cost": 1}
	s["cb3"] = {"branch": "combat", "name": "Power Strike", "desc": "Unlocks the heavy attack (hold the attack button).", "req": "cb2", "cost": 1}
	s["cb4"] = {"branch": "combat", "name": "Whirlwind", "desc": "Unlocks a spin attack when dodging out of a combo.", "req": "cb3", "cost": 2}
	s["cb5"] = {"branch": "combat", "name": "Vitality", "desc": "+30 maximum health.", "req": "cb4", "cost": 2}
	s["en1"] = {"branch": "engineering", "name": "Efficient Builder", "desc": "Structures cost 20% fewer materials.", "req": "", "cost": 1}
	s["en2"] = {"branch": "engineering", "name": "Quick Hands", "desc": "Crafting is 35% faster.", "req": "en1", "cost": 1}
	s["en3"] = {"branch": "engineering", "name": "Advanced Blueprints", "desc": "Unlocks advanced recipes (energy blade, crystal tools).", "req": "en2", "cost": 2}
	s["en4"] = {"branch": "engineering", "name": "Salvager", "desc": "Salvage and kills may drop extra machine components.", "req": "en3", "cost": 1}
	s["en5"] = {"branch": "engineering", "name": "Overclock", "desc": "Turrets and processors work 40% faster.", "req": "en4", "cost": 2}
	return s
