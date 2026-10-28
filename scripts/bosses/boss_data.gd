class_name BossData
extends RefCounted
## Data-driven boss definitions. Attacks are small scripts of steps run by Boss: every attack starts with a telegraph
## and most end with a vulnerability window ("vuln"), so the player can always read what is coming and punish it.
##
## step ops: tele t | wait t | vuln t | wave speed kind dmg | lob n spread dmg kind | volley n spread speed kind dmg |
##           ring n speed kind dmg | rain n kind dmg | column n spacing dmg kind mode | dash speed | leap |
##           blink | beam a0 a1 dur dmg | summon kind n | fly_to x_frac y_px t | tile ice | melee reach h dmg t |
##           shake amp | sfx name | say text

const DATA := {
	"meadow_colossus": {
		"name": "Meadow Colossus", "hp": 720.0, "size": Vector2(118, 168), "flying": false, "walk": 40.0, "contact": 18.0,
		"phases": [
			{"at": 1.0, "speed": 1.0, "pool": ["slam", "boulders", "sweep"]},
			{"at": 0.62, "speed": 1.12, "pool": ["slam", "boulders", "sweep", "vines"], "say": "The Colossus tears vines from its shoulders!"},
			{"at": 0.3, "speed": 1.28, "pool": ["leap", "vines", "slam", "boulders"], "say": "The Colossus roars. It is no longer holding back!"},
		],
		"attacks": {
			"slam": [["tele", 0.9], ["wave", 300.0, "shard", 18.0], ["shake", 6.0], ["vuln", 1.4]],
			"boulders": [["tele", 0.7], ["lob", 3, 0.35, 16.0, "boulder"], ["wait", 0.6], ["vuln", 0.9]],
			"sweep": [["tele", 0.8], ["melee", 170.0, 46.0, 22.0, 0.28], ["vuln", 1.1]],
			"vines": [["tele", 0.7], ["column", 3, 150.0, 18.0, "vine", "near"], ["wait", 1.0], ["vuln", 0.8]],
			"leap": [["tele", 0.7], ["leap"], ["wave", 280.0, "shard", 16.0], ["vuln", 1.3]],
		},
	},
	"furnace_behemoth": {
		"name": "Furnace Behemoth", "hp": 900.0, "size": Vector2(130, 150), "flying": false, "walk": 50.0, "contact": 20.0,
		"phases": [
			{"at": 1.0, "speed": 1.0, "pool": ["breath", "ram", "fire_columns"]},
			{"at": 0.62, "speed": 1.12, "pool": ["breath", "ram", "fire_columns", "lava_rain"], "say": "Furnace vents burst open. Lava rains from the ceiling!"},
			{"at": 0.3, "speed": 1.3, "pool": ["ram", "lava_rain", "fire_columns", "breath"], "say": "The Behemoth overheats. It charges faster!"},
		],
		"attacks": {
			"breath": [["tele", 0.8], ["volley", 5, 0.14, 270.0, "flame", 14.0], ["wait", 0.5], ["volley", 5, 0.14, 270.0, "flame", 14.0], ["vuln", 1.1]],
			"ram": [["tele", 0.9], ["dash", 560.0], ["vuln", 0.2]],
			"fire_columns": [["tele", 0.8], ["column", 4, 130.0, 20.0, "flame", "near"], ["wait", 1.0], ["vuln", 1.0]],
			"lava_rain": [["tele", 0.6], ["rain", 6, "flame", 16.0], ["wait", 1.7], ["vuln", 0.9]],
		},
	},
	"astral_watcher": {
		"name": "Astral Watcher", "hp": 980.0, "size": Vector2(108, 108), "flying": true, "walk": 70.0, "contact": 16.0,
		"phases": [
			{"at": 1.0, "speed": 1.0, "pool": ["beam", "orbs", "blink"]},
			{"at": 0.62, "speed": 1.12, "pool": ["beam", "orbs", "blink", "stars"], "say": "Stars begin to fall in the flooded dome."},
			{"at": 0.3, "speed": 1.25, "pool": ["beam", "stars", "blink", "orbs"], "say": "The Watcher's eye burns white."},
		],
		"attacks": {
			"beam": [["fly_to", 0.5, 220.0, 0.8], ["tele", 1.0], ["beam", 15.0, 165.0, 2.2, 20.0], ["vuln", 1.7]],
			"orbs": [["tele", 0.7], ["ring", 12, 200.0, "orb", 12.0], ["wait", 0.8], ["ring", 12, 170.0, "orb", 12.0], ["vuln", 0.9]],
			"stars": [["tele", 0.6], ["rain", 5, "shard", 14.0], ["wait", 1.3], ["vuln", 0.6]],
			"blink": [["blink"], ["tele", 0.5], ["volley", 3, 0.25, 300.0, "orb", 13.0], ["vuln", 1.0]],
		},
	},
	"thorn_queen": {
		"name": "Thorn Queen", "hp": 1100.0, "size": Vector2(96, 164), "flying": false, "walk": 55.0, "contact": 16.0,
		"phases": [
			{"at": 1.0, "speed": 1.0, "pool": ["roots", "spores", "whip"]},
			{"at": 0.62, "speed": 1.12, "pool": ["roots", "spores", "whip", "summon"], "say": "The Queen calls her stalkers."},
			{"at": 0.3, "speed": 1.28, "pool": ["roots", "spores", "whip", "summon"], "say": "Thorns erupt everywhere. The Queen is desperate!"},
		],
		"attacks": {
			"roots": [["tele", 0.8], ["column", 6, 120.0, 16.0, "thorn", "line"], ["wait", 1.2], ["vuln", 1.0]],
			"spores": [["tele", 0.7], ["lob", 4, 0.5, 13.0, "spore"], ["wait", 0.6], ["vuln", 0.9]],
			"whip": [["tele", 0.7], ["melee", 200.0, 64.0, 20.0, 0.3], ["vuln", 1.1]],
			"summon": [["tele", 1.0], ["summon", "stalker", 2], ["vuln", 1.6]],
		},
	},
	"frostbound_king": {
		"name": "Frostbound King", "hp": 1250.0, "size": Vector2(92, 152), "flying": false, "walk": 60.0, "contact": 20.0,
		"phases": [
			{"at": 1.0, "speed": 1.0, "pool": ["ice_slash", "nova", "bash"]},
			{"at": 0.62, "speed": 1.12, "pool": ["ice_slash", "nova", "bash", "icicles"], "say": "The floor freezes over. Footing is treacherous!", "tile": "ice"},
			{"at": 0.3, "speed": 1.28, "pool": ["icicles", "nova", "bash", "ice_slash"], "say": "The King's armour cracks, but he fights on."},
		],
		"attacks": {
			"ice_slash": [["tele", 0.7], ["wave", 350.0, "shard", 18.0], ["wait", 0.4], ["wave", 350.0, "shard", 18.0], ["vuln", 1.0]],
			"nova": [["tele", 0.9], ["ring", 16, 230.0, "shard", 14.0], ["vuln", 1.2]],
			"icicles": [["tele", 0.6], ["rain", 7, "shard", 16.0], ["wait", 1.5], ["vuln", 0.7]],
			"bash": [["tele", 0.8], ["dash", 520.0], ["vuln", 0.2]],
		},
	},
	"clockwork_sovereign": {
		"name": "Clockwork Sovereign", "hp": 1450.0, "size": Vector2(150, 176), "flying": false, "walk": 45.0, "contact": 22.0,
		"phases": [
			{"at": 1.0, "speed": 1.0, "pool": ["gears", "pistons", "grid"]},
			{"at": 0.62, "speed": 1.15, "pool": ["gears", "pistons", "grid", "overclock"], "say": "The Sovereign overclocks. Use Stasis to stop its gears!"},
			{"at": 0.3, "speed": 1.3, "pool": ["gears", "pistons", "grid", "overclock"], "say": "Every gear spins at once."},
		],
		"attacks": {
			"gears": [["tele", 0.7], ["wave", 240.0, "gear", 16.0], ["wait", 0.8], ["wave", 240.0, "gear", 16.0], ["vuln", 1.0]],
			"pistons": [["tele", 0.8], ["column", 6, 150.0, 22.0, "gear", "near"], ["wait", 1.0], ["vuln", 1.0]],
			"grid": [["tele", 1.0], ["volley", 7, 0.2, 280.0, "gear", 13.0], ["wait", 0.6], ["volley", 7, 0.2, 280.0, "gear", 13.0], ["vuln", 1.1]],
			"overclock": [["tele", 0.6], ["rain", 6, "gear", 15.0], ["wait", 1.0], ["dash", 600.0]],
		},
	},
	"eclipse_architect": {
		"name": "Eclipse Architect", "hp": 2100.0, "size": Vector2(84, 148), "flying": true, "walk": 80.0, "contact": 18.0,
		"phases": [
			{"at": 1.0, "speed": 1.0, "pool": ["bolts", "teleslash", "stars"]},
			{"at": 0.72, "speed": 1.1, "pool": ["bolts", "teleslash", "stars", "sun"], "say": "The Architect raises a black sun."},
			{"at": 0.45, "speed": 1.2, "pool": ["bolts", "teleslash", "sun", "summon", "stars"], "say": "Wraiths pour out of the eclipse."},
			{"at": 0.22, "speed": 1.35, "pool": ["bolts", "teleslash", "sun", "stars", "beam"], "say": "\"Come home, Starheart!\""},
		],
		"attacks": {
			"bolts": [["tele", 0.6], ["volley", 5, 0.5, 300.0, "void", 14.0], ["wait", 0.35], ["volley", 5, 0.5, 300.0, "void", 14.0], ["vuln", 1.0]],
			"teleslash": [["blink"], ["tele", 0.55], ["melee", 190.0, 100.0, 22.0, 0.26], ["vuln", 1.0]],
			"stars": [["tele", 0.6], ["rain", 7, "shard", 15.0], ["wait", 1.4], ["vuln", 0.8]],
			"sun": [["tele", 0.9], ["volley", 1, 0.0, 130.0, "sun", 22.0], ["wait", 1.2], ["vuln", 1.3]],
			"summon": [["tele", 1.0], ["summon", "wraith", 2], ["vuln", 1.6]],
			"beam": [["fly_to", 0.5, 230.0, 0.7], ["tele", 1.0], ["beam", 10.0, 170.0, 2.0, 22.0], ["vuln", 1.5]],
		},
	},
}
