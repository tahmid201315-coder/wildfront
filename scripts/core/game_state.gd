extends Node
## Central game state (autoload "Game"): state machine, player stats, progression,
## creature collection, discovery log and settings.

enum State { MENU, LOADING, PLAY, PAUSE, INVENTORY, CRAFTING, BUILDING, DIALOGUE, DEFEAT, RECOVERY }

signal state_changed(new_state: int)
signal stats_changed
signal xp_changed
signal leveled_up(level: int, unlocks: Array)
signal notify(text: String, kind: String)
signal species_discovered(id: String)
signal collection_changed
signal companion_changed
signal settings_changed
signal region_entered(id: String)

const MAX_LEVEL := 20
const SETTINGS_DEFAULT := {
	"cam_sens": 1.0, "cam_invert": false, "quality": 1, "render_scale": 1.0, "fps": 30,
	"vol_master": 0.8, "vol_music": 0.6, "vol_sfx": 0.8, "vibration": true, "ui_scale": 1.0,
}

var state: int = State.MENU
var _state_stack: Array = []
var world: Node = null          # set by the world scene while it is active
var pending_continue: bool = false
var menu_message: String = ""

# Player stats
var max_health: float = 100.0
var health: float = 100.0
var stamina: float = 100.0
var hunger: float = 100.0
var comfort: float = 70.0
var heat_resist: float = 0.0     # seconds of Cooling Tonic remaining
var level: int = 1
var xp: int = 0

# Journal / discovery
var discovered_species: Dictionary = {}
var visited_regions: Dictionary = {}
var found_landmarks: Dictionary = {}
var lore_found: Dictionary = {}
var crafted_once: Dictionary = {}
var dismissed_hints: Dictionary = {}
var explored: PackedByteArray = PackedByteArray()
const EXPLORE_N := 60            # 60 x 60 cells of 4 m cover the 240 m world
const EXPLORE_CELL := 4.0

# Creature collection
var creatures: Array = []        # [{uid, species, name, level, xp, bond, hp, favorite, assigned}]
var active_uid: String = ""
var next_uid: int = 1
var wild_taken: Dictionary = {}  # spawn_id -> seconds until respawn

# Settings
var settings: Dictionary = SETTINGS_DEFAULT.duplicate(true)
var play_seconds: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().set_auto_accept_quit(false)
	_setup_input()
	reset_progress()
	load_settings()


func _setup_input() -> void:
	var map := {"move_left": KEY_A, "move_right": KEY_D, "move_forward": KEY_W, "move_back": KEY_S,
		"jump": KEY_SPACE, "act": KEY_E, "run": KEY_SHIFT, "strike": KEY_F, "ability": KEY_Q}
	for a in map:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
			var ev := InputEventKey.new()
			ev.physical_keycode = map[a]
			InputMap.action_add_event(a, ev)


# ------------------------------------------------------------ lifecycle
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			_autosave_now()
			get_tree().quit()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			if world and world.has_method("on_back_requested"):
				world.on_back_requested()
		NOTIFICATION_APPLICATION_PAUSED:
			_autosave_now()
			if world and world.has_method("on_app_paused"):
				world.on_app_paused()
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			if world and world.has_method("on_app_paused"):
				world.on_app_paused()


func _autosave_now() -> void:
	if world and world.has_method("save_now") and state != State.MENU and state != State.DEFEAT:
		world.save_now(true)


# ------------------------------------------------------------ state machine
func set_state(s: int) -> void:
	if s == state:
		return
	state = s
	# Simulation pauses for full-screen menus. BUILDING keeps the world running.
	var paused := s in [State.PAUSE, State.INVENTORY, State.CRAFTING, State.DIALOGUE, State.DEFEAT, State.RECOVERY, State.LOADING]
	get_tree().paused = paused
	state_changed.emit(s)


func push_state(s: int) -> void:
	_state_stack.append(state)
	set_state(s)


func pop_state() -> void:
	var prev: int = State.PLAY
	if not _state_stack.is_empty():
		prev = _state_stack.pop_back()
	set_state(prev)


func clear_state_stack() -> void:
	_state_stack.clear()


func is_playing() -> bool:
	return state == State.PLAY or state == State.BUILDING


# ------------------------------------------------------------ new game / reset
func reset_progress() -> void:
	max_health = 100.0
	health = 100.0
	stamina = 100.0
	hunger = 100.0
	comfort = 70.0
	heat_resist = 0.0
	level = 1
	xp = 0
	discovered_species = {}
	visited_regions = {}
	found_landmarks = {}
	lore_found = {}
	crafted_once = {}
	dismissed_hints = {}
	creatures = []
	active_uid = ""
	next_uid = 1
	wild_taken = {}
	play_seconds = 0.0
	explored = PackedByteArray()
	explored.resize(EXPLORE_N * EXPLORE_N)
	explored.fill(0)
	_state_stack.clear()


# ------------------------------------------------------------ xp / levels
func xp_needed(lv: int = -1) -> int:
	if lv < 0:
		lv = level
	return 100 + (lv - 1) * 60


func add_xp(amount: int, _reason: String = "") -> void:
	if amount <= 0 or level >= MAX_LEVEL:
		return
	xp += amount
	var unlocks: Array = []
	while level < MAX_LEVEL and xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		max_health += 5.0
		health = max_health
		for rid in Data.recipes:
			if Data.recipes[rid]["level"] == level:
				unlocks.append("Recipe: " + Data.recipes[rid]["name"])
		leveled_up.emit(level, unlocks)
	xp_changed.emit()


func mark_crafted(item_id: String) -> void:
	if not crafted_once.has(item_id):
		crafted_once[item_id] = true
		add_xp(10, "first craft")


# ------------------------------------------------------------ discovery
func discover_species(id: String) -> bool:
	if discovered_species.has(id):
		return false
	discovered_species[id] = true
	species_discovered.emit(id)
	add_xp(15, "discovery")
	Quests.notify_event("discover", id)
	toast("Discovered: " + Data.creatures[id]["name"], "discover")
	return true


func visit_region(id: String) -> void:
	if visited_regions.has(id):
		return
	visited_regions[id] = true
	add_xp(int(Data.regions[id]["xp"]), "region")
	region_entered.emit(id)
	Quests.notify_event("region", id)
	toast("Entered " + Data.regions[id]["name"], "discover")


func visit_landmark(id: String) -> void:
	if found_landmarks.has(id):
		return
	found_landmarks[id] = true
	var lm: Dictionary = Data.landmarks[id]
	add_xp(int(lm["xp"]), "landmark")
	unlock_lore(lm["lore"])
	Quests.notify_event("landmark", id)
	if id != "camp":
		toast("Found: " + lm["name"], "discover")


func unlock_lore(id: String) -> void:
	if Data.lore.has(id) and not lore_found.has(id):
		lore_found[id] = true


func reveal_area(wx: float, wz: float, radius: float) -> void:
	var half := Data.WORLD_HALF
	var r_cells := int(ceil(radius / EXPLORE_CELL))
	var cx := int((wx + half) / EXPLORE_CELL)
	var cz := int((wz + half) / EXPLORE_CELL)
	for dz in range(-r_cells, r_cells + 1):
		for dx in range(-r_cells, r_cells + 1):
			if dx * dx + dz * dz > r_cells * r_cells:
				continue
			var x := cx + dx
			var z := cz + dz
			if x >= 0 and z >= 0 and x < EXPLORE_N and z < EXPLORE_N:
				explored[z * EXPLORE_N + x] = 1


# ------------------------------------------------------------ creature collection
func add_creature(species: String) -> Dictionary:
	if not Data.creatures.has(species) or Data.creatures[species].get("hostile", false):
		push_warning("add_creature: invalid species %s" % species)
		return {}
	var def: Dictionary = Data.creatures[species]
	var c := {"uid": "c%d" % next_uid, "species": species, "name": def["name"], "level": 1, "xp": 0,
		"bond": 10.0, "hp": float(def["hp"]), "favorite": false, "assigned": ""}
	next_uid += 1
	creatures.append(c)
	if active_uid == "":
		set_active(c["uid"])
	collection_changed.emit()
	return c


func find_creature(uid: String) -> Dictionary:
	for c in creatures:
		if c["uid"] == uid:
			return c
	return {}


func active_creature() -> Dictionary:
	return find_creature(active_uid)


func set_active(uid: String) -> void:
	if uid != "" and find_creature(uid).is_empty():
		return
	if uid != "":
		find_creature(uid)["assigned"] = ""
	active_uid = uid
	companion_changed.emit()
	collection_changed.emit()


func release_creature(uid: String) -> void:
	for i in creatures.size():
		if creatures[i]["uid"] == uid:
			creatures.remove_at(i)
			break
	if active_uid == uid:
		active_uid = ""
		companion_changed.emit()
	collection_changed.emit()


func creature_max_hp(c: Dictionary) -> float:
	return float(Data.creatures[c["species"]]["hp"]) * (1.0 + 0.1 * (int(c["level"]) - 1))


func creature_add_xp(uid: String, amount: int) -> void:
	var c := find_creature(uid)
	if c.is_empty():
		return
	c["xp"] += amount
	while c["xp"] >= 40 + int(c["level"]) * 20 and int(c["level"]) < 10:
		c["xp"] -= 40 + int(c["level"]) * 20
		c["level"] += 1
		toast("%s reached level %d!" % [c["name"], c["level"]], "level")
	collection_changed.emit()


# ------------------------------------------------------------ player stats
func damage_player(amount: float) -> void:
	health = clampf(health - maxf(amount, 0.0), 0.0, max_health)
	stats_changed.emit()


func heal_player(amount: float) -> void:
	health = clampf(health + maxf(amount, 0.0), 0.0, max_health)
	stats_changed.emit()


func feed_player(amount: float) -> void:
	hunger = clampf(hunger + maxf(amount, 0.0), 0.0, 100.0)
	stats_changed.emit()


## Consume an item from the pack. Returns true when something was consumed.
func use_item(id: String) -> bool:
	var d: Dictionary = Data.get_item(id)
	if d.is_empty() or Inv.count(id) <= 0:
		return false
	var kind: String = d["kind"]
	if kind != "food" and kind != "consumable":
		return false
	if d.has("trust"):
		toast("Offer this to a Wildling using the action button.", "info")
		return false
	if not (d.has("hunger") or d.has("heal") or d.has("heat_resist")):
		return false
	if d.has("hunger") and not d.has("heal") and hunger >= 99.0:
		toast("You are not hungry.", "info")
		return false
	if not Inv.remove(id, 1):
		return false
	if d.has("hunger"):
		feed_player(float(d["hunger"]))
	if d.has("heal"):
		heal_player(float(d["heal"]))
	if d.has("heat_resist"):
		heat_resist = float(d["heat_resist"])
	Sfx.play("eat")
	stats_changed.emit()
	return true


## Add to the pack; anything that does not fit is dropped as a pickup near the player.
func give_item(id: String, n: int) -> void:
	var left := Inv.add(id, n)
	if left > 0:
		if world and world.has_method("spawn_pickup_near_player"):
			world.spawn_pickup_near_player(id, left)
			toast("Pack full! Dropped %d %s nearby." % [left, Data.item_name(id)], "warn")
		else:
			toast("Pack full! Lost %d %s." % [left, Data.item_name(id)], "warn")


func toast(text: String, kind: String = "info") -> void:
	notify.emit(text, kind)


# ------------------------------------------------------------ settings
func load_settings() -> void:
	var loaded: Dictionary = Save.load_settings()
	settings = SETTINGS_DEFAULT.duplicate(true)
	for k in loaded:
		if settings.has(k) and typeof(loaded[k]) == typeof(settings[k]):
			settings[k] = loaded[k]
		elif settings.has(k) and typeof(settings[k]) == TYPE_FLOAT and typeof(loaded[k]) == TYPE_INT:
			settings[k] = float(loaded[k])
		elif settings.has(k) and typeof(settings[k]) == TYPE_INT and typeof(loaded[k]) == TYPE_FLOAT:
			settings[k] = int(loaded[k])
	apply_settings()


func set_setting(key: String, value: Variant) -> void:
	if not settings.has(key):
		push_warning("Unknown setting " + key)
		return
	settings[key] = value
	apply_settings()
	Save.save_settings(settings)


func apply_settings() -> void:
	Engine.max_fps = int(settings["fps"])
	Sfx.apply_volumes()
	var root := get_tree().root
	if root:
		root.content_scale_factor = clampf(float(settings["ui_scale"]), 0.75, 1.5)
		root.scaling_3d_scale = clampf(float(settings["render_scale"]), 0.5, 1.0)
	settings_changed.emit()


# ------------------------------------------------------------ save / load of this module
func serialize() -> Dictionary:
	return {
		"health": health, "max_health": max_health, "stamina": stamina, "hunger": hunger, "comfort": comfort,
		"heat_resist": heat_resist, "level": level, "xp": xp,
		"discovered": discovered_species.keys(), "regions": visited_regions.keys(),
		"landmarks": found_landmarks.keys(), "lore": lore_found.keys(), "crafted": crafted_once.keys(),
		"hints": dismissed_hints.keys(), "explored": Marshalls.raw_to_base64(explored),
		"creatures": creatures.duplicate(true), "active": active_uid, "next_uid": next_uid,
		"wild_taken": wild_taken.duplicate(), "play_seconds": play_seconds,
	}


func deserialize(d: Dictionary) -> void:
	reset_progress()
	max_health = float(d.get("max_health", 100.0))
	health = clampf(float(d.get("health", max_health)), 1.0, max_health)
	stamina = clampf(float(d.get("stamina", 100.0)), 0.0, 100.0)
	hunger = clampf(float(d.get("hunger", 100.0)), 0.0, 100.0)
	comfort = clampf(float(d.get("comfort", 70.0)), 0.0, 100.0)
	heat_resist = maxf(float(d.get("heat_resist", 0.0)), 0.0)
	level = clampi(int(d.get("level", 1)), 1, MAX_LEVEL)
	xp = maxi(int(d.get("xp", 0)), 0)
	for k in d.get("discovered", []):
		if Data.creatures.has(k):
			discovered_species[k] = true
	for k in d.get("regions", []):
		if Data.regions.has(k):
			visited_regions[k] = true
	for k in d.get("landmarks", []):
		if Data.landmarks.has(k):
			found_landmarks[k] = true
	for k in d.get("lore", []):
		if Data.lore.has(k):
			lore_found[k] = true
	for k in d.get("crafted", []):
		crafted_once[k] = true
	for k in d.get("hints", []):
		dismissed_hints[k] = true
	var ex: PackedByteArray = Marshalls.base64_to_raw(str(d.get("explored", "")))
	if ex.size() == EXPLORE_N * EXPLORE_N:
		explored = ex
	for c in d.get("creatures", []):
		if typeof(c) == TYPE_DICTIONARY and Data.creatures.has(c.get("species", "")):
			var cc: Dictionary = {"uid": str(c.get("uid", "c0")), "species": c["species"], "name": str(c.get("name", "")),
				"level": int(c.get("level", 1)), "xp": int(c.get("xp", 0)), "bond": float(c.get("bond", 10.0)),
				"hp": float(c.get("hp", 10.0)), "favorite": bool(c.get("favorite", false)), "assigned": str(c.get("assigned", ""))}
			creatures.append(cc)
	active_uid = str(d.get("active", ""))
	if find_creature(active_uid).is_empty():
		active_uid = ""
	next_uid = maxi(int(d.get("next_uid", creatures.size() + 1)), creatures.size() + 1)
	var wt: Dictionary = d.get("wild_taken", {})
	for k in wt:
		wild_taken[k] = maxf(float(wt[k]), 0.0)
	play_seconds = maxf(float(d.get("play_seconds", 0.0)), 0.0)
