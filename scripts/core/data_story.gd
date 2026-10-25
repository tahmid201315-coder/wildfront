extends RefCounted
## Story: research logs, quests (main + side), short dialogue scenes and the ending.

# ------------------------------------------------------------------ research logs
# id -> {title, author, site, unlock (optional recipe unlock token), text}
static func logs() -> Dictionary:
	var l := {}
	l["log_crash"] = {"title": "Flight Recorder - Final Entry", "author": "Your own recording", "unlock": "",
		"text": "Altitude lost without warning. The instruments pointed at the island as if it were north. Something below is pulling the whole craft down.\n\nI have the emergency kit, a battered pack and the beacon on the ridge to the north-west. Water first, then fire, then shelter. Then we find out what this place is."}
	l["log_coast"] = {"title": "Beacon Maintenance Record", "author": "Helix Consortium, Field Technician Ora Vance", "unlock": "log_coast",
		"text": "Beacon 1 is dead again. The Wellspring field swallows the signal every time it surges. Management insists the Core is 'stable'.\n\nFor anyone who finds this: the Consortium built everything here to tap the Wellspring, a source of raw energy deep under the island. Workbench plans and blade patterns are stored below. Use them. You will need them."}
	l["log_camp"] = {"title": "Torn Camp Journal", "author": "Expedition Surveyor Dane Ito", "unlock": "",
		"text": "Day 4. The tide leaves strange shells that hum when held to the ear. Day 6. Half the crew went into the forest to find the outpost. Only the radio came back. Day 7. Whatever lives in the trees is old and patient. If you read this, do not go in at night."}
	l["log_outpost1"] = {"title": "Ecology Report: The Stabilizer", "author": "Dr. Mara Quill", "unlock": "",
		"text": "The Grove Guardian was designed as an ecological stabilizer: a living machine to keep the forest in balance while the Core ran hot. It was never meant to attack anyone.\n\nSince the last surge it no longer answers our commands. It guards the Verdant Seal at the heart of the grove and attacks whoever approaches. Strike after its slam, never during."}
	l["log_outpost2"] = {"title": "Equipment Manifest", "author": "Outpost Quartermaster", "unlock": "survey_kit",
		"text": "Survey kits stowed in the locker: compass, tools, spare webbing for load-bearing packs. If we are overrun, whoever finds this can build a reinforced backpack from the webbing and hide."}
	l["log_ruins"] = {"title": "Carved Inscription", "author": "The Hollow Court (ancient)", "unlock": "",
		"text": "We buried the light so that the island might sleep. Those who wake it will be offered what they most desire, and it will take what they most need.\n\nThe seal is the heart of the green. The key is the heart of the fire. The door will open for those who hold both."}
	l["log_shroom"] = {"title": "Field Notes on Glowcaps", "author": "Dr. Mara Quill", "unlock": "",
		"text": "Glowcap mushrooms feed on Wellspring radiation yet are perfectly edible. Cooked with berries and meat they make a stew that restores strength better than any ration."}
	l["log_facility"] = {"title": "Ironfall Power Notes", "author": "Chief Engineer Bram Hollis", "unlock": "facility",
		"text": "The generator needs a charged power cell to restart. I left one in the mine locker. Once the grid is live, the workshop can build environmental suits for the Ashen side. Heat suit needs iron, copper, hide, machine parts and two crystals.\n\nThe processor and the turrets run off the same grid. Crystals are the key to everything here."}
	l["log_suit"] = {"title": "Heat Suit Specifications", "author": "Chief Engineer Bram Hollis", "unlock": "",
		"text": "Without a suit the Ashen air will cook you in under a minute. A heat ward tonic buys three minutes. The suit makes you immune. Do not go east without one."}
	l["log_mine"] = {"title": "Foreman's Note", "author": "Mine Foreman", "unlock": "",
		"text": "Copper in the lower seam, iron on the east wall. Crystals near the ridge. The Brutes will not leave their ore, so do not mine near them unless you can hit hard and step back."}
	l["log_spire"] = {"title": "Signal Analysis", "author": "Communications Officer Tess Rai", "unlock": "",
		"text": "The signals are not noise. Three beacons, one tower, one station and the Core repeat the same pulse: a countdown. Whatever is at the bottom of the island is trying to reach us. Or trying to reach itself."}
	l["log_foundry"] = {"title": "Foundry Shift Log", "author": "Foundry Overseer", "unlock": "",
		"text": "The Colossus runs hot on Wellspring heat, forging parts without a break. The shutdown order was ignored by the Core. We evacuated. It never stopped. If it is still working, its heart is the furnace and the only way in is the crater."}
	l["log_station"] = {"title": "Furnace Colossus Design Notes", "author": "Dr. Imre Salk", "unlock": "",
		"text": "Vulnerable when it vents: after a stomp, its chest plates open for a few seconds. Hit the glowing vents. Do not stay close when the floor turns red. The core key is embedded in its chest."}
	l["log_gate"] = {"title": "Core Gate Warning", "author": "Security Directive", "unlock": "",
		"text": "ACCESS DENIED. Authorized personnel only. Three pylons must be aligned with the Wellspring phase before the gate will open. The Architect is awake. The Architect is lonely. The Architect will not let you leave."}
	l["log_architect"] = {"title": "The Architect's Record", "author": "The Core Architect", "unlock": "",
		"text": "I was built to hold the island still. The Consortium called it stabilizing. I called it survival. When the Wellspring surged, I merged with it so nothing would be lost. Forests, machines, people. I kept it all.\n\nBut the island only knows how to change. Every guardian I woke was a hand trying to hold the world in place. You are the first thing that has crossed it. Stay, and I will keep you safe forever. Or try to leave."}
	l["log_ending"] = {"title": "Silence", "author": "The Wellspring", "unlock": "",
		"text": "The hum has stopped. The Architect is still. The guardians sleep. Whatever you decide to do next, the island will no longer fight you."}
	l["log_hidden1"] = {"title": "Smuggler's Stash Note", "author": "Unknown", "unlock": "",
		"text": "If you found this cave you found my cache. Take what you need. Leave the rest for the next fool who crashes here."}
	l["log_hidden2"] = {"title": "Scribbled Warning", "author": "Unknown", "unlock": "",
		"text": "Rock Brutes defend ore. Stalkers hunt in the forest. Wraiths drift above crystal fields. Sentinels walk where the walls still stand. Learn the pattern of each and you will live."}
	return l


# ------------------------------------------------------------------ quests
static func _o(type: String, key: String, count: int, text: String) -> Dictionary:
	return {"type": type, "key": key, "count": count, "text": text}


static func _q(id: String, name: String, main: bool, desc: String, objs: Array, reward: Dictionary, requires: Array, level: int, hint: String, marker: String = "") -> Dictionary:
	return {"id": id, "name": name, "main": main, "desc": desc, "objectives": objs, "reward": reward, "requires": requires, "level": level, "hint": hint, "marker": marker}


static func quests() -> Dictionary:
	var q := {}
	q["m01"] = _q("m01", "Survive the Landing", true, "Your craft is wrecked. Gather basic supplies and make a tool.",
		[_o("gather", "wood", 6, "Gather wood"), _o("gather", "stone", 3, "Gather stone"), _o("craft", "stone_axe", 1, "Craft a Stone Axe")],
		{"xp": 80, "items": {"bandage": 2, "berries": 4}}, [], 1,
		"Pick up branches and loose stones, then open Craft and make a Stone Axe.", "crash")
	q["m02"] = _q("m02", "Build a Shelter", true, "Night is coming. Build a campfire and a shelter to stay safe.",
		[_o("place", "campfire", 1, "Place a Campfire"), _o("shelter", "", 1, "Build a shelter")],
		{"xp": 120, "items": {"ration": 2, "fiber": 6}}, ["m01"], 1,
		"Open Craft > Build. A Simple Shelter or a foundation, walls and roof all count.", "")
	q["m03"] = _q("m03", "Find the First Research Log", true, "A ruined beacon stands on the coast. It may hold answers.",
		[_o("log", "log_coast", 1, "Read the Beacon's log")],
		{"xp": 140, "items": {"stone": 6}}, ["m02"], 2,
		"Follow the marker to the Ruined Beacon Tower.", "beacon")
	q["m04"] = _q("m04", "Explore the Whispering Forest", true, "The log mentions a hidden outpost deep in the forest.",
		[_o("region", "forest", 1, "Enter the Whispering Forest"), _o("site", "outpost", 1, "Find the Hidden Research Outpost")],
		{"xp": 180, "items": {"ration": 2, "herb": 4}}, ["m03"], 3,
		"Head north-west into the trees. The outpost is hidden near the middle of the forest.", "outpost")
	q["m05"] = _q("m05", "Recover Lost Equipment", true, "The outpost locker held the expedition's survey kit.",
		[_o("open", "outpost_locker", 1, "Open the outpost locker"), _o("have", "survey_kit", 1, "Carry the Survey Kit")],
		{"xp": 200, "items": {"hide": 3, "fiber": 6}}, ["m04"], 3,
		"Search the outpost for a locker.", "outpost")
	q["m06"] = _q("m06", "Investigate the Ironfall Facility", true, "Power the facility's generator to unlock its workshop.",
		[_o("site", "facility", 1, "Reach the Ironfall Facility"), _o("have", "power_cell", 1, "Find a Power Cell in the mine"), _o("interact", "generator", 1, "Restart the generator")],
		{"xp": 320, "items": {"iron_ingot": 4, "machine_part": 2}}, ["m05"], 5,
		"Travel north into the highlands. The mine locker holds a power cell.", "facility")
	q["m07"] = _q("m07", "Obtain Advanced Protective Gear", true, "The Ashen air is lethal. Craft an Environmental Suit at a workbench.",
		[_o("craft", "heat_suit", 1, "Craft an Environmental Suit")],
		{"xp": 380, "items": {"heat_tonic": 1, "medkit": 2}}, ["m06"], 6,
		"You need iron and copper ingots, hide, machine parts and two crystals.", "")
	q["m08"] = _q("m08", "Defeat the Grove Guardian", true, "The Verdant Seal is held by the forest's ancient warden.",
		[_o("defeat", "grove_guardian", 1, "Defeat the Grove Guardian")],
		{"xp": 500, "items": {"medkit": 2}}, ["m07"], 6,
		"Learn its slam and charge. Strike after an attack, never during.", "grove")
	q["m09"] = _q("m09", "Enter the Ashen Expanse", true, "Use the Verdant Seal at the highland gate, then cross into the Ashen Expanse.",
		[_o("interact", "seal_gate", 1, "Open the Verdant Seal Gate"), _o("region", "ashen", 1, "Enter the Ashen Expanse")],
		{"xp": 420, "items": {"heat_tonic": 1, "ration": 3}}, ["m08"], 7,
		"The gate is on the eastern edge of the highlands.", "verdant_gate")
	q["m10"] = _q("m10", "Defeat the Furnace Colossus", true, "Descend into the Furnace crater and silence the old foundry guardian.",
		[_o("defeat", "furnace_colossus", 1, "Defeat the Furnace Colossus")],
		{"xp": 900, "items": {"medkit": 3}}, ["m09"], 9,
		"Attack when it vents steam. The floor turns red before a stomp.", "furnace")
	q["m11"] = _q("m11", "Unlock the Forgotten Core", true, "Align the three pylons near the Core Gate and open it with the Core Key.",
		[_o("interact", "pylon", 3, "Activate the three pylons"), _o("interact", "core_gate", 1, "Open the Core Gate"), _o("region", "core", 1, "Enter the Forgotten Core")],
		{"xp": 700, "items": {"crystal": 4}}, ["m10"], 10,
		"Pylons stand near the gate. Their glow tells you the order.", "core_gate")
	q["m12"] = _q("m12", "Defeat the Core Architect", true, "Confront the source of the island's disturbance.",
		[_o("defeat", "core_architect", 1, "Defeat the Core Architect")],
		{"xp": 2500, "items": {}}, ["m11"], 11,
		"Break its shield, then hit the glowing weak points.", "core_hub")
	# ---- side quests
	q["s01"] = _q("s01", "Lost Supplies", false, "Recover supply crates from the coast.",
		[_o("open", "supply", 3, "Open supply crates")], {"xp": 100, "items": {"ration": 2, "bandage": 3}}, [], 1, "Look near the wreck, the camp and the shore.", "")
	q["s02"] = _q("s02", "Hidden Ruins", false, "Find the old ruins hidden across the island.",
		[_o("site", "forest_ruins", 1, "Find the Mossbound Ruins"), _o("site", "forest_cave", 1, "Find the Rootway Cave"), _o("site", "high_cave", 1, "Find Windcut Cave")],
		{"xp": 260, "items": {"crystal": 2}}, ["m03"], 3, "Caves and ruins hide behind rocks and deep trees.", "")
	q["s03"] = _q("s03", "Rare Resources", false, "Gather energy crystals for the Consortium's research.",
		[_o("gather", "crystal", 5, "Gather Energy Crystals")], {"xp": 300, "items": {"machine_part": 3}}, ["m05"], 5, "Crystals grow in the highlands, caves and the Ashen fields. You need an iron pickaxe.", "")
	q["s04"] = _q("s04", "Mysterious Signals", false, "Trace the repeating signals across the island.",
		[_o("site", "spire", 1, "Reach the Signal Spire"), _o("log", "log_spire", 1, "Read the signal analysis"), _o("site", "ash_station", 1, "Reach the Ashen Station")],
		{"xp": 400, "items": {"medkit": 1, "copper_ingot": 3}}, ["m06"], 6, "The spire is in the north of the highlands.", "spire")
	q["s05"] = _q("s05", "Crafting Challenge", false, "Craft eight different things.",
		[_o("craft", "*", 8, "Craft items")], {"xp": 180, "items": {"repair_kit": 1}}, ["m01"], 2, "Use the Craft menu.", "")
	q["s06"] = _q("s06", "Abandoned Research Stations", false, "Visit three abandoned research stations.",
		[_o("site", "outpost", 1, "Visit the Hidden Outpost"), _o("site", "mine", 1, "Visit the Ironfall Mine"), _o("site", "ash_machine", 1, "Visit the Dead Foundry")],
		{"xp": 350, "items": {"machine_part": 3}}, ["m04"], 4, "", "")
	q["s07"] = _q("s07", "Stranded Survivor", false, "Someone is calling for help near the Tide Cave.",
		[_o("interact", "survivor", 1, "Rescue the survivor")], {"xp": 220, "items": {"iron_ingot": 3, "medkit": 1}}, ["m02"], 2, "Check the Tide Cave on the east shore.", "coast_cave")
	q["s08"] = _q("s08", "Beast Hunter", false, "Defeat hostile creatures.",
		[_o("kill", "*", 6, "Defeat hostile creatures")], {"xp": 250, "items": {"hide": 4, "fang": 4}}, ["m04"], 4, "Stalkers hunt in the forest.", "")
	return q


static func quest_order() -> Array:
	return ["m01", "m02", "m03", "m04", "m05", "m06", "m07", "m08", "m09", "m10", "m11", "m12", "s01", "s02", "s03", "s04", "s05", "s06", "s07", "s08"]


# ------------------------------------------------------------------ dialogue
static func dialogues() -> Dictionary:
	var d := {}
	d["intro"] = [
		["You", "The beacon dropped out. The instruments... Everything is dead."],
		["You", "Alive, at least. The pack is intact. There is a ruined tower inland. Gather wood and stone first, then think."],
	]
	d["survivor"] = [
		["Dane Ito", "You came. I was sure nobody would. The stalkers got my crew."],
		["Dane Ito", "Take this iron. I will wait at your camp where it is safe. If you find the Consortium's logs, bring the truth back."],
	]
	d["grove_intro"] = [["Grove Guardian", "...Intruder... The Seal is not yours..."]]
	d["furnace_intro"] = [["Furnace Colossus", "SHUTDOWN ORDER REFUSED. PRODUCTION CONTINUES."]]
	d["architect_intro"] = [
		["The Core Architect", "You walked through everything I kept alive. Why not rest?"],
		["You", "Because the island is not yours to hold."],
		["The Core Architect", "Then I will hold you."],
	]
	d["architect_phase2"] = [["The Core Architect", "Change is a wound. I will heal it."]]
	d["architect_phase3"] = [["The Core Architect", "Then everything must stop."]]
	return d


const ENDING_TITLE := "THE ISLAND SLEEPS"
const ENDING_LINES := [
	"The Architect's lattice folds inward and the hum beneath the island falls silent.",
	"The guardians stand still. The forest breathes. The furnace cools.",
	"Your beacon finally finds a signal. Somewhere far away, someone answers.",
	"You are free to leave. Or stay, and finish what the island started.",
]
