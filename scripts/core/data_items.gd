extends RefCounted
## Item definitions. cat: resource, food, medicine, tool, weapon, armor, suit, pack, quest.
## icon: kind drawn by the UI icon painter + colour. All numbers are gameplay-balanced values.

static func _i(name: String, cat: String, stack: int, desc: String, icon: String, col: Color, extra: Dictionary = {}) -> Dictionary:
	var d := {"name": name, "cat": cat, "stack": stack, "desc": desc, "icon": icon, "col": col}
	d.merge(extra)
	return d


static func build() -> Dictionary:
	var it := {}
	# --- resources
	it["wood"] = _i("Wood", "resource", 40, "Sturdy timber from the island's trees.", "log", Color(0.62, 0.42, 0.24))
	it["stone"] = _i("Stone", "resource", 40, "Rough stone, good for tools and walls.", "stone", Color(0.62, 0.62, 0.64))
	it["fiber"] = _i("Plant Fiber", "resource", 40, "Tough fibres for lashing and bandages.", "fiber", Color(0.55, 0.72, 0.30))
	it["hide"] = _i("Creature Hide", "resource", 30, "Thick hide from a hunted animal.", "hide", Color(0.66, 0.46, 0.30))
	it["fang"] = _i("Predator Fang", "resource", 30, "A sharp fang. Useful for weapons.", "fang", Color(0.93, 0.90, 0.80))
	it["iron_ore"] = _i("Iron Ore", "resource", 40, "Rust-flecked ore. Smelt it in a campfire.", "ore", Color(0.74, 0.40, 0.24))
	it["copper_ore"] = _i("Copper Ore", "resource", 40, "Green-veined copper ore.", "ore", Color(0.28, 0.72, 0.58))
	it["iron_ingot"] = _i("Iron Ingot", "resource", 30, "Smelted iron, ready for forging.", "ingot", Color(0.70, 0.74, 0.80))
	it["copper_ingot"] = _i("Copper Ingot", "resource", 30, "Smelted copper for wiring and alloys.", "ingot", Color(0.86, 0.52, 0.30))
	it["crystal"] = _i("Energy Crystal", "resource", 20, "A rare crystal humming with stored energy.", "crystal", Color(0.35, 0.85, 1.0))
	it["machine_part"] = _i("Machine Component", "resource", 20, "Salvaged precision parts from old machinery.", "part", Color(0.60, 0.64, 0.70))
	it["ember_core"] = _i("Ember Core", "resource", 10, "A fist-sized lump of living heat.", "crystal", Color(1.0, 0.50, 0.20))
	# --- food
	it["berries"] = _i("Sunberries", "food", 30, "Sweet wild berries.", "berry", Color(0.86, 0.20, 0.30), {"hunger": 12.0})
	it["coconut"] = _i("Coconut", "food", 20, "Hunger and a little stamina.", "coconut", Color(0.46, 0.32, 0.20), {"hunger": 10.0, "stamina": 20.0})
	it["mushroom"] = _i("Glowcap Mushroom", "food", 30, "Earthy and filling. Better cooked.", "mushroom", Color(0.84, 0.50, 0.70), {"hunger": 9.0})
	it["raw_meat"] = _i("Raw Meat", "food", 20, "Safe to eat only when cooked. Eating it raw sickens you.", "meat", Color(0.82, 0.32, 0.32), {"hunger": 8.0, "health": -8.0})
	it["cooked_meat"] = _i("Cooked Meat", "food", 20, "Hot, hearty and satisfying.", "cooked", Color(0.70, 0.40, 0.22), {"hunger": 38.0, "health": 6.0})
	it["stew"] = _i("Forager's Stew", "food", 10, "Restores hunger and refills stamina.", "stew", Color(0.78, 0.50, 0.20), {"hunger": 52.0, "stamina": 40.0})
	it["ration"] = _i("Survey Ration", "food", 20, "A sealed ration pack from the old expedition.", "ration", Color(0.45, 0.62, 0.74), {"hunger": 45.0})
	# --- medicine
	it["bandage"] = _i("Healing Bandage", "medicine", 20, "Restores 30 health.", "bandage", Color(0.95, 0.95, 0.92), {"health": 30.0})
	it["herb"] = _i("Medicinal Herb", "medicine", 30, "A bitter herb. Restores a little health.", "herb", Color(0.35, 0.78, 0.40), {"health": 10.0})
	it["herb_tonic"] = _i("Herbal Tonic", "medicine", 10, "Restores 65 health.", "tonic", Color(0.40, 0.86, 0.46), {"health": 65.0})
	it["medkit"] = _i("Field Medkit", "medicine", 5, "Restores 120 health.", "medkit", Color(0.92, 0.28, 0.28), {"health": 120.0})
	it["heat_tonic"] = _i("Heat Ward Tonic", "medicine", 5, "Protects you from heat for three minutes.", "tonic", Color(1.0, 0.62, 0.30), {"heat_ward": 180.0})
	it["repair_kit"] = _i("Repair Kit", "medicine", 10, "Restores 60% durability to the equipped weapon.", "kit", Color(0.78, 0.78, 0.82), {"repair": 0.6})
	# --- tools (tier gates resources; power multiplies gather speed)
	it["stone_axe"] = _i("Stone Axe", "tool", 1, "Chops trees quickly.", "axe", Color(0.66, 0.66, 0.68), {"tool": "axe", "tier": 1, "power": 1.8, "dur": 120})
	it["stone_pickaxe"] = _i("Stone Pickaxe", "tool", 1, "Mines stone and soft ores.", "pick", Color(0.66, 0.66, 0.68), {"tool": "pick", "tier": 1, "power": 1.8, "dur": 120})
	it["iron_axe"] = _i("Iron Axe", "tool", 1, "A far better axe.", "axe", Color(0.78, 0.82, 0.90), {"tool": "axe", "tier": 2, "power": 2.8, "dur": 260})
	it["iron_pickaxe"] = _i("Iron Pickaxe", "tool", 1, "Mines crystals and salvage.", "pick", Color(0.78, 0.82, 0.90), {"tool": "pick", "tier": 2, "power": 2.8, "dur": 260})
	it["crystal_axe"] = _i("Crystal Axe", "tool", 1, "Energy-edged. Fells trees in a blink.", "axe", Color(0.45, 0.9, 1.0), {"tool": "axe", "tier": 3, "power": 4.2, "dur": 600})
	it["crystal_pickaxe"] = _i("Crystal Pickaxe", "tool", 1, "Cuts through anything.", "pick", Color(0.45, 0.9, 1.0), {"tool": "pick", "tier": 3, "power": 4.2, "dur": 600})
	# --- weapons: dmg, reach(m), cd(s), cost(stamina), style, dur
	it["wooden_spear"] = _i("Wooden Spear", "weapon", 1, "Long reach, light damage.", "spear", Color(0.62, 0.45, 0.28), {"dmg": 14.0, "reach": 3.0, "cd": 0.55, "cost": 8.0, "style": "spear", "dur": 70})
	it["stone_blade"] = _i("Stone Blade", "weapon", 1, "A balanced chipped-stone sword.", "blade", Color(0.72, 0.72, 0.76), {"dmg": 22.0, "reach": 2.3, "cd": 0.5, "cost": 9.0, "style": "blade", "dur": 100})
	it["reinforced_blade"] = _i("Reinforced Blade", "weapon", 1, "Iron-forged and dependable.", "blade", Color(0.80, 0.86, 0.95), {"dmg": 36.0, "reach": 2.5, "cd": 0.48, "cost": 10.0, "style": "blade", "dur": 190})
	it["energy_blade"] = _i("Energy Blade", "weapon", 1, "A humming crystal-edged sword.", "energy_blade", Color(0.40, 0.9, 1.0), {"dmg": 56.0, "reach": 2.7, "cd": 0.42, "cost": 11.0, "style": "blade", "dur": 400})
	it["crystal_cannon"] = _i("Crystal Cannon", "weapon", 1, "Fires energy bolts. Uses 1 crystal per 8 shots.", "cannon", Color(0.5, 0.85, 1.0), {"dmg": 48.0, "reach": 40.0, "cd": 0.7, "cost": 6.0, "style": "ranged", "dur": 0})
	it["thorn_edge"] = _i("Guardian's Thorn", "weapon", 1, "A living-wood blade taken from the Grove Guardian.", "blade", Color(0.45, 0.82, 0.35), {"dmg": 46.0, "reach": 2.7, "cd": 0.46, "cost": 10.0, "style": "blade", "dur": 300})
	it["magma_blade"] = _i("Magma Edge", "weapon", 1, "Forged in the Furnace Colossus's heart.", "blade", Color(1.0, 0.5, 0.2), {"dmg": 78.0, "reach": 2.9, "cd": 0.44, "cost": 11.0, "style": "blade", "dur": 400})
	# --- armour: def = flat damage reduction %, slot armor / suit / pack
	it["hide_armor"] = _i("Hide Armor", "armor", 1, "Layered hide. Warm and sturdy.", "armor", Color(0.66, 0.46, 0.30), {"slot": "armor", "def": 0.14, "cold": 0.35})
	it["iron_armor"] = _i("Iron Armor", "armor", 1, "Riveted iron plates.", "armor", Color(0.74, 0.78, 0.86), {"slot": "armor", "def": 0.26, "cold": 0.2})
	it["crystal_armor"] = _i("Crystal Armor", "armor", 1, "Energy-laced composite armor.", "armor", Color(0.45, 0.88, 1.0), {"slot": "armor", "def": 0.40, "cold": 0.5})
	it["heat_suit"] = _i("Environmental Suit", "suit", 1, "Fully protects against extreme heat.", "suit", Color(0.95, 0.70, 0.25), {"slot": "suit", "heat": 1.0, "def": 0.08})
	it["backpack_2"] = _i("Reinforced Backpack", "pack", 1, "Adds 12 inventory slots.", "pack", Color(0.50, 0.62, 0.42), {"slot": "pack", "slots": 12})
	it["backpack_3"] = _i("Expedition Pack", "pack", 1, "Adds 24 inventory slots.", "pack", Color(0.30, 0.55, 0.85), {"slot": "pack", "slots": 24})
	# --- quest items
	it["survey_kit"] = _i("Survey Kit", "quest", 1, "Lost expedition equipment. Someone will want it.", "kit", Color(0.35, 0.62, 0.80))
	it["verdant_seal"] = _i("Verdant Seal", "quest", 1, "A seal of living stone. Opens the gate to the Ashen Expanse.", "seal", Color(0.45, 0.85, 0.40))
	it["power_cell"] = _i("Power Cell", "quest", 1, "A charged cell from the Ironfall generator room.", "cell", Color(0.4, 0.9, 1.0))
	it["core_key"] = _i("Core Key", "quest", 1, "A keycard forged in the Furnace. Opens the Forgotten Core.", "key", Color(1.0, 0.55, 0.25))
	return it
