extends RefCounted
## World layout: regions and landmark sites. World is 512 m square, centred on (0,0); +Z is south.

const WORLD_SIZE := 512.0
const CELL := 512.0 / 192.0       # terrain cell size in metres
const GRID_N := 192               # cells per side
const CHUNK_CELLS := 32           # cells per terrain chunk side
const SEA_LEVEL := 0.0

const REGIONS := {
	"coast": {
		"name": "Greenhaven Coast", "center": Vector2(0, 175), "radius": 108.0,
		"blurb": "Sun-bleached beaches, palms and the wreck of your landing craft.",
		"temp": 0.0, "xp": 20,
	},
	"forest": {
		"name": "Whispering Forest", "center": Vector2(-105, 45), "radius": 110.0,
		"blurb": "Dense woods where something old watches from the dark between the trunks.",
		"temp": 0.0, "xp": 40,
	},
	"highlands": {
		"name": "Ironfall Highlands", "center": Vector2(-70, -135), "radius": 118.0,
		"blurb": "Wind-scoured cliffs, ore seams and the rusting ruins of an industrial age.",
		"temp": -0.5, "xp": 60,
	},
	"ashen": {
		"name": "Ashen Expanse", "center": Vector2(105, -110), "radius": 108.0,
		"blurb": "Black ground, steam vents and a furnace that never went out.",
		"temp": 1.0, "xp": 80,
	},
	"core": {
		"name": "Forgotten Core", "center": Vector2(140, 55), "radius": 78.0,
		"blurb": "A sealed caldera. Something beneath the island hums with cold light.",
		"temp": 0.0, "xp": 120,
	},
}

const REGION_ORDER := ["coast", "forest", "highlands", "ashen", "core"]

# kind decides what gets built there. flat = radius of levelled ground.
const SITES := {
	"crash":        {"region": "coast",     "pos": Vector2(0, 150),      "flat": 15.0, "kind": "crash", "name": "Landing Craft Wreck"},
	"camp_coast":   {"region": "coast",     "pos": Vector2(-48, 180),    "flat": 10.0, "kind": "campsite", "name": "Abandoned Campsite"},
	"beacon":       {"region": "coast",     "pos": Vector2(-34, 112),    "flat": 9.0,  "kind": "beacon", "name": "Ruined Beacon Tower"},
	"coast_cave":   {"region": "coast",     "pos": Vector2(62, 150),     "flat": 8.0,  "kind": "cave", "name": "Tide Cave"},
	"forest_gate":  {"region": "forest",    "pos": Vector2(-52, 92),     "flat": 8.0,  "kind": "arch", "name": "Overgrown Gate"},
	"outpost":      {"region": "forest",    "pos": Vector2(-128, 62),    "flat": 14.0, "kind": "outpost", "name": "Hidden Research Outpost"},
	"forest_ruins": {"region": "forest",    "pos": Vector2(-88, 12),     "flat": 13.0, "kind": "ruins", "name": "Mossbound Ruins"},
	"forest_cave":  {"region": "forest",    "pos": Vector2(-96, 104),    "flat": 8.0,  "kind": "cave", "name": "Rootway Cave"},
	"shroom":       {"region": "forest",    "pos": Vector2(-60, 46),     "flat": 9.0,  "kind": "mushrooms", "name": "Mushroom Hollow"},
	"grove":        {"region": "forest",    "pos": Vector2(-168, -8),    "flat": 26.0, "kind": "grove_arena", "name": "Guardian's Grove"},
	"elder_oak":    {"region": "forest",    "pos": Vector2(-130, 10),    "flat": 10.0, "kind": "elder_oak", "name": "The Elder Oak"},
	"facility":     {"region": "highlands", "pos": Vector2(-72, -150),   "flat": 24.0, "kind": "facility", "name": "Ironfall Facility"},
	"mine":         {"region": "highlands", "pos": Vector2(-32, -118),   "flat": 12.0, "kind": "mine", "name": "Ironfall Mine"},
	"high_cave":    {"region": "highlands", "pos": Vector2(-112, -118),  "flat": 8.0,  "kind": "cave", "name": "Windcut Cave"},
	"spire":        {"region": "highlands", "pos": Vector2(-44, -182),   "flat": 10.0, "kind": "spire", "name": "Signal Spire"},
	"verdant_gate": {"region": "highlands", "pos": Vector2(-5, -120),    "flat": 12.0, "kind": "seal_gate", "name": "Verdant Seal Gate"},
	"ash_machine":  {"region": "ashen",     "pos": Vector2(62, -92),     "flat": 14.0, "kind": "machinery", "name": "Dead Foundry"},
	"furnace":      {"region": "ashen",     "pos": Vector2(112, -118),   "flat": 30.0, "kind": "furnace_arena", "name": "The Furnace"},
	"ash_station":  {"region": "ashen",     "pos": Vector2(158, -138),   "flat": 12.0, "kind": "station", "name": "Ashen Research Station"},
	"vents":        {"region": "ashen",     "pos": Vector2(138, -62),    "flat": 12.0, "kind": "vents", "name": "Steam Vent Field"},
	"core_gate":    {"region": "core",      "pos": Vector2(140, -18),    "flat": 12.0, "kind": "core_gate", "name": "Core Gate"},
	"core_hub":     {"region": "core",      "pos": Vector2(140, 52),     "flat": 44.0, "kind": "core_facility", "name": "Central Facility"},
}

# Player respawn / start
const START_POS := Vector2(6, 128)
