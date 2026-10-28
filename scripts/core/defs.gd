class_name Defs
extends RefCounted
## Static game data: regions, skills, equipment, enemies. Pure data, no behaviour.

const REGION_ORDER := ["meadows", "ember", "observatory", "thornwild", "frostfall", "clockwork", "eclipse"]

const REGIONS := {
	"meadows": {"name": "Whispering Meadows", "boss": "meadow_colossus", "music": "meadows",
		"blurb": "Green floating islands, stone bridges and quiet waterfalls.",
		"sky_top": Color(0.35, 0.62, 0.9), "sky_bot": Color(0.86, 0.93, 0.97), "ground": Color(0.42, 0.34, 0.26), "accent": Color(0.45, 0.78, 0.35),
		"stone": Color(0.62, 0.62, 0.6), "glow": Color(0.6, 0.9, 1.0), "hazard": "spikes", "map_pos": Vector2(0.18, 0.62)},
	"ember": {"name": "Emberforge Caverns", "boss": "furnace_behemoth", "music": "ember",
		"blurb": "Volcanic tunnels, rivers of lava and abandoned mining machines.",
		"sky_top": Color(0.14, 0.04, 0.05), "sky_bot": Color(0.45, 0.12, 0.05), "ground": Color(0.24, 0.18, 0.17), "accent": Color(1.0, 0.5, 0.15),
		"stone": Color(0.36, 0.28, 0.27), "glow": Color(1.0, 0.55, 0.2), "hazard": "lava", "map_pos": Vector2(0.34, 0.42)},
	"observatory": {"name": "Sunken Observatory", "boss": "astral_watcher", "music": "observatory",
		"blurb": "Drowned astronomy halls lit by cold blue stars.",
		"sky_top": Color(0.03, 0.07, 0.2), "sky_bot": Color(0.1, 0.3, 0.45), "ground": Color(0.18, 0.26, 0.34), "accent": Color(0.4, 0.85, 1.0),
		"stone": Color(0.3, 0.4, 0.5), "glow": Color(0.5, 0.9, 1.0), "hazard": "water", "map_pos": Vector2(0.5, 0.7)},
	"thornwild": {"name": "Thornwild Forest", "boss": "thorn_queen", "music": "thornwild",
		"blurb": "Colossal roots, glowing mushrooms and poisonous thorns.",
		"sky_top": Color(0.05, 0.16, 0.1), "sky_bot": Color(0.2, 0.42, 0.25), "ground": Color(0.25, 0.18, 0.12), "accent": Color(0.7, 0.35, 0.85),
		"stone": Color(0.3, 0.38, 0.22), "glow": Color(0.8, 0.5, 1.0), "hazard": "thorns", "map_pos": Vector2(0.62, 0.36)},
	"frostfall": {"name": "Frostfall Citadel", "boss": "frostbound_king", "music": "frostfall",
		"blurb": "Frozen halls, icy bridges and a never-ending storm.",
		"sky_top": Color(0.35, 0.45, 0.6), "sky_bot": Color(0.85, 0.92, 1.0), "ground": Color(0.6, 0.72, 0.85), "accent": Color(0.75, 0.95, 1.0),
		"stone": Color(0.5, 0.62, 0.78), "glow": Color(0.8, 0.95, 1.0), "hazard": "icicles", "map_pos": Vector2(0.78, 0.2)},
	"clockwork": {"name": "The Clockwork Abyss", "boss": "clockwork_sovereign", "music": "clockwork",
		"blurb": "Gears the size of towns turn in the dark below the clouds.",
		"sky_top": Color(0.08, 0.07, 0.05), "sky_bot": Color(0.3, 0.22, 0.1), "ground": Color(0.3, 0.26, 0.2), "accent": Color(0.95, 0.75, 0.3),
		"stone": Color(0.42, 0.36, 0.28), "glow": Color(1.0, 0.8, 0.35), "hazard": "gears", "map_pos": Vector2(0.84, 0.56)},
	"eclipse": {"name": "The Eclipse Realm", "boss": "eclipse_architect", "music": "eclipse",
		"blurb": "Broken architecture drifts under a black sun.",
		"sky_top": Color(0.02, 0.0, 0.06), "sky_bot": Color(0.25, 0.08, 0.3), "ground": Color(0.16, 0.1, 0.22), "accent": Color(0.95, 0.35, 0.8),
		"stone": Color(0.26, 0.18, 0.36), "glow": Color(1.0, 0.5, 0.9), "hazard": "void", "map_pos": Vector2(0.5, 0.12)},
}

# id: name, desc, max level, cost per level (skill points), effect per level
const SKILLS := {
	"vitality": {"name": "Vitality", "desc": "+20 maximum health per level.", "max": 5, "cost": 1, "branch": "body"},
	"aether": {"name": "Aether Well", "desc": "+15 maximum magic energy per level.", "max": 4, "cost": 1, "branch": "body"},
	"mending": {"name": "Mending Light", "desc": "Healing restores +12 health per level.", "max": 3, "cost": 1, "branch": "body"},
	"edge": {"name": "Keen Edge", "desc": "+12% light attack damage per level.", "max": 4, "cost": 1, "branch": "blade"},
	"crusher": {"name": "Crusher", "desc": "+15% heavy attack damage per level.", "max": 4, "cost": 1, "branch": "blade"},
	"focus": {"name": "Swift Recovery", "desc": "Magic energy regenerates 15% faster per level.", "max": 3, "cost": 1, "branch": "magic"},
	"windstep": {"name": "Windstep", "desc": "Dash recovers 12% faster per level and travels further.", "max": 3, "cost": 1, "branch": "magic"},
	"gatherer": {"name": "Shard Magnet", "desc": "+15% Star Shards from enemies per level.", "max": 3, "cost": 1, "branch": "body"},
}

# slot: boots, charm, pendant, lens
const EQUIPMENT := {
	"windrunner_boots": {"name": "Windrunner Boots", "slot": "boots", "desc": "+10% run speed and better air control.", "stats": {"speed": 0.10, "air": 0.35}},
	"ember_charm": {"name": "Ember Charm", "slot": "charm", "desc": "+25% damage against molten and plant enemies, immune to lava splashes.", "stats": {"fire": 0.25}},
	"guardian_pendant": {"name": "Guardian Pendant", "slot": "pendant", "desc": "Take 20% less damage.", "stats": {"defense": 0.20}},
	"astral_lens": {"name": "Astral Lens", "slot": "lens", "desc": "Reveals hidden walls and secret rooms.", "stats": {"reveal": 1.0}},
	"frost_band": {"name": "Frost Band", "slot": "charm", "desc": "Ice no longer makes you slide; +10% heavy damage.", "stats": {"ice": 1.0, "heavy": 0.10}},
	"gearwright_gloves": {"name": "Gearwright Gloves", "slot": "boots", "desc": "Dash cooldown reduced by 25%.", "stats": {"dash_cd": 0.25}},
	"thorn_veil": {"name": "Thorn Veil", "slot": "pendant", "desc": "Thorns and poison deal half damage.", "stats": {"thorn": 0.5}},
	"eclipse_mantle": {"name": "Eclipse Mantle", "slot": "lens", "desc": "Magic costs 25% less energy.", "stats": {"magic_cost": 0.25}},
}

const SLOTS := ["boots", "charm", "pendant", "lens"]

# Difficulty multipliers.
const DIFFICULTY := [
	{"name": "Story", "enemy_hp": 0.7, "enemy_dmg": 0.6, "aggro": 0.8, "heals": 2},
	{"name": "Adventurer", "enemy_hp": 1.0, "enemy_dmg": 1.0, "aggro": 1.0, "heals": 0},
	{"name": "Veteran", "enemy_hp": 1.35, "enemy_dmg": 1.4, "aggro": 1.25, "heals": -1},
]
