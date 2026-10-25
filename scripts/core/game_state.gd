extends Node
## Autoload "Game": state machine, player stats, progression, discoveries, equipment and settings.

enum State { MENU, LOADING, PLAY, PAUSE, INVENTORY, BUILDING, DIALOGUE, DEFEAT, ENDING }

signal state_changed(new_state: int)
signal stats_changed
signal xp_changed
signal leveled_up(level: int)
signal notify(text: String, kind: String)
signal equipment_changed
signal region_entered(id: String)
signal progress_changed             # stats / flags that quests care about
signal settings_changed

const MAX_LEVEL := 25
const BASE_SLOTS := 24
const SETTINGS_DEFAULT := {
	"cam_sens": 1.0, "cam_invert": false, "quality": 1, "perf_mode": false, "fps": 30, "render_scale": 1.0,
	"vol_master": 0.8, "vol_music": 0.55, "vol_sfx": 0.8, "vibration": true, "ui_scale": 1.0,
	"left_handed": false, "btn_scale": 1.0,
}

var state: int = State.MENU
var _state_stack: Array = []
var world: Node = null
var pending_continue: bool = false
var menu_message: String = ""

# vitals
var max_health: float = 100.0
var health: float = 100.0
var stamina: float = 100.0
var hunger: float = 100.0
var temperature: float = 50.0           # 0 freezing .. 50 comfortable .. 100 scorching
var heat_ward: float = 0.0              # seconds of heat protection left from a tonic

# progression
var level: int = 1
var xp: int = 0
var skill_points: int = 0
var skills: Dictionary = {}             # skill id -> true

# equipment slots: slot -> {id, dur}
var equip: Dictionary = {}

# discovery & story flags
var unlocks: Dictionary = {}
var logs_read: Dictionary = {}
var sites_found: Dictionary = {}
var regions_seen: Dictionary = {}
var bosses_defeated: Dictionary = {}
var opened: Dictionary = {}             # one-time container ids and group counters
var flags: Dictionary = {}              # seal_gate_open, core_gate_open, generator_on, survivor_rescued, pylons, ending_seen ...
var stats: Dictionary = {}              # "gather:wood" -> count, "kill:*" ...
var waypoint: Variant = null            # Vector2 world x,z or null
var respawn_pos: Vector3 = Vector3.ZERO
var death_cache: Dictionary = {}        # {"pos": [x,y,z], "items": [...]}
var day_count: int = 1
var time_of_day: float = 0.32
var play_seconds: float = 0.0
var explored: PackedByteArray = PackedByteArray()
const EXPLORE_N := 64                   # fog-of-war cells over the 512 m island (8 m each)

var settings: Dictionary = SETTINGS_DEFAULT.duplicate(true)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().set_auto_accept_quit(false)
	_setup_input()
	reset_progress()
	load_settings()


func _setup_input() -> void:
	var map := {"move_left": KEY_A, "move_right": KEY_D, "move_forward": KEY_W, "move_back": KEY_S,
		"jump": KEY_SPACE, "act": KEY_E, "run": KEY_SHIFT, "attack": KEY_F, "dodge": KEY_C, "heavy": KEY_R}
	for a in map:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
			var ev := InputEventKey.new()
			ev.physical_keycode = map[a]
			InputMap.action_add_event(a, ev)


# ------------------------------------------------------------- lifecycle
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
	if world and world.has_method("save_now") and state != State.MENU and state != State.DEFEAT and state != State.LOADING:
		world.save_now(true)


# ------------------------------------------------------------- state machine
func set_state(s: int) -> void:
	if s == state:
		return
	state = s
	var paused := s in [State.PAUSE, State.INVENTORY, State.DIALOGUE, State.DEFEAT, State.LOADING, State.ENDING]
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


# ------------------------------------------------------------- reset / new game
func reset_progress() -> void:
	max_health = 100.0
	health = 100.0
	stamina = 100.0
	hunger = 100.0
	temperature = 50.0
	heat_ward = 0.0
	level = 1
	xp = 0
	skill_points = 0
	skills = {}
	equip = {}
	unlocks = {}
	logs_read = {}
	sites_found = {}
	regions_seen = {}
	bosses_defeated = {}
	opened = {}
	flags = {}
	stats = {}
	waypoint = null
	death_cache = {}
	day_count = 1
	time_of_day = 0.32
	play_seconds = 0.0
	respawn_pos = Vector3.ZERO
	explored = PackedByteArray()
	explored.resize(EXPLORE_N * EXPLORE_N)
	_state_stack.clear()
	recompute_limits()


func recompute_limits() -> void:
	max_health = 100.0 + (level - 1) * 2.0 + (30.0 if has_skill("cb5") else 0.0)
	health = minf(health, max_health)


# ------------------------------------------------------------- progression
func xp_needed(lv: int = -1) -> int:
	var l := level if lv < 0 else lv
	return 90 + (l - 1) * 70


func add_xp(amount: int, _reason: String = "") -> void:
	if amount <= 0 or level >= MAX_LEVEL:
		return
	xp += amount
	while level < MAX_LEVEL and xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		skill_points += 1
		recompute_limits()
		health = max_health
		leveled_up.emit(level)
		toast("Level %d! You earned a skill point." % level, "level")
	xp_changed.emit()
	stats_changed.emit()


func has_skill(id: String) -> bool:
	return skills.has(id)


func can_learn(id: String) -> String:
	if not Data.skills.has(id):
		return "Unknown skill."
	if skills.has(id):
		return "Already learned."
	var s: Dictionary = Data.skills[id]
	if s["req"] != "" and not skills.has(s["req"]):
		return "Requires %s first." % Data.skills[s["req"]]["name"]
	if skill_points < int(s["cost"]):
		return "Not enough skill points."
	return ""


func learn_skill(id: String) -> bool:
	if can_learn(id) != "":
		return false
	skill_points -= int(Data.skills[id]["cost"])
	skills[id] = true
	recompute_limits()
	if id == "cb5":
		health = minf(health + 30.0, max_health)
	toast("Learned: " + Data.skills[id]["name"], "level")
	stats_changed.emit()
	progress_changed.emit()
	return true


func unlocked(token: String) -> bool:
	if token == "":
		return true
	if token == "skill_adv":
		return skills.has("en3")
	if token.begins_with("level:"):
		return level >= int(token.substr(6))
	return unlocks.has(token)


func grant_unlock(token: String) -> void:
	if token != "" and not unlocks.has(token):
		unlocks[token] = true
		progress_changed.emit()


# ------------------------------------------------------------- stats / flags (quest feed)
func stat(key: String) -> int:
	return int(stats.get(key, 0))


func add_stat(key: String, n: int = 1) -> void:
	stats[key] = stat(key) + n
	progress_changed.emit()


func set_flag(key: String, value: Variant = true) -> void:
	flags[key] = value
	progress_changed.emit()


func flag(key: String) -> bool:
	return bool(flags.get(key, false))


func read_log(id: String) -> void:
	if not Data.logs.has(id):
		return
	var first := not logs_read.has(id)
	logs_read[id] = true
	var tok: String = Data.logs[id].get("unlock", "")
	if tok != "":
		grant_unlock(tok)
	if first:
		add_xp(25, "log")
		toast("Research log recorded: " + Data.logs[id]["title"], "discover")
	progress_changed.emit()


func found_site(id: String) -> void:
	if sites_found.has(id) or not Data.sites.has(id):
		return
	sites_found[id] = true
	add_xp(30, "site")
	toast("Discovered: " + Data.sites[id]["name"], "discover")
	progress_changed.emit()


func enter_region(id: String) -> void:
	if not regions_seen.has(id):
		regions_seen[id] = true
		add_xp(int(Data.regions[id]["xp"]), "region")
		toast("Entering " + Data.regions[id]["name"], "region")
		progress_changed.emit()
	region_entered.emit(id)


func defeat_boss(id: String) -> void:
	bosses_defeated[id] = true
	var tok: String = Data.bosses[id]["unlock"]
	grant_unlock(tok)
	add_xp(int(Data.bosses[id]["xp"]), "boss")
	progress_changed.emit()


func reveal_area(wx: float, wz: float, radius: float) -> void:
	var cell := Data.DW.WORLD_SIZE / EXPLORE_N
	var cx := int((wx + Data.DW.WORLD_SIZE * 0.5) / cell)
	var cz := int((wz + Data.DW.WORLD_SIZE * 0.5) / cell)
	var r := int(ceil(radius / cell))
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dz * dz > r * r:
				continue
			var x := cx + dx
			var z := cz + dz
			if x >= 0 and z >= 0 and x < EXPLORE_N and z < EXPLORE_N:
				explored[z * EXPLORE_N + x] = 1


func is_explored(wx: float, wz: float) -> bool:
	var cell := Data.DW.WORLD_SIZE / EXPLORE_N
	var x := int((wx + Data.DW.WORLD_SIZE * 0.5) / cell)
	var z := int((wz + Data.DW.WORLD_SIZE * 0.5) / cell)
	if x < 0 or z < 0 or x >= EXPLORE_N or z >= EXPLORE_N:
		return false
	return explored[z * EXPLORE_N + x] == 1


# ------------------------------------------------------------- vitals
func damage_player(amount: float) -> void:
	health = maxf(health - amount, 0.0)
	stats_changed.emit()


func heal_player(amount: float) -> void:
	health = minf(health + amount, max_health)
	stats_changed.emit()


func feed_player(amount: float) -> void:
	hunger = clampf(hunger + amount, 0.0, 100.0)
	stats_changed.emit()


## Gives items to the player; anything that does not fit is dropped at their feet (never lost).
func give_item(id: String, n: int) -> void:
	var left := Inv.add(id, n)
	if left > 0:
		if world and world.has_method("drop_pickup"):
			world.drop_pickup(id, left)
			toast("Pack full: %d x %s dropped nearby." % [left, Data.item_name(id)], "warn")
		else:
			toast("Pack full: %s lost." % Data.item_name(id), "warn")


func toast(text: String, kind: String = "info") -> void:
	notify.emit(text, kind)


## Heat protection 0..1 from suit, tonic and skill.
func heat_protection() -> float:
	var p := 0.0
	if equip.has("suit") and Data.items[equip["suit"]["id"]].get("heat", 0.0) > 0.0:
		p = maxf(p, float(Data.items[equip["suit"]["id"]]["heat"]))
	if heat_ward > 0.0:
		p = 1.0
	if has_skill("sv4"):
		p = minf(p + 0.25, 1.0)
	return p


func cold_protection() -> float:
	var p := 0.0
	if equip.has("armor"):
		p = float(Data.items[equip["armor"]["id"]].get("cold", 0.0))
	if has_skill("sv4"):
		p = minf(p + 0.25, 1.0)
	return p


func damage_reduction() -> float:
	var r := 0.0
	for slot in ["armor", "suit"]:
		if equip.has(slot):
			r += float(Data.items[equip[slot]["id"]].get("def", 0.0))
	return clampf(r, 0.0, 0.7)


func slots_capacity() -> int:
	var extra := 0
	if equip.has("pack"):
		extra = int(Data.items[equip["pack"]["id"]].get("slots", 0))
	return BASE_SLOTS + extra


func weapon_item() -> Dictionary:
	if equip.has("weapon"):
		return Data.items[equip["weapon"]["id"]]
	return {"name": "Fists", "dmg": 6.0, "reach": 1.6, "cd": 0.5, "cost": 5.0, "style": "fist", "dur": 0}


## Consumes one item of the given id if it is usable. Returns true if consumed.
func use_item(id: String) -> bool:
	if not Data.items.has(id):
		return false
	var it: Dictionary = Data.items[id]
	var mult := 1.25 if has_skill("sv5") else 1.0
	var used := false
	if it.has("hunger"):
		if hunger >= 99.0 and not (it.has("health") or it.has("stamina")):
			toast("You are not hungry.", "info")
			return false
		feed_player(float(it["hunger"]) * mult)
		used = true
	if it.has("stamina"):
		stamina = minf(stamina + float(it["stamina"]), 100.0)
		used = true
	if it.has("health"):
		var hv := float(it["health"])
		if hv > 0.0 and health >= max_health - 0.5 and not it.has("hunger"):
			toast("Health is already full.", "info")
			return false
		if hv > 0.0:
			heal_player(hv * mult)
		else:
			damage_player(-hv)
		used = true
	if it.has("heat_ward"):
		heat_ward = float(it["heat_ward"])
		toast("You feel protected from the heat.", "info")
		used = true
	if it.has("repair"):
		if equip.has("weapon") and int(Data.items[equip["weapon"]["id"]].get("dur", 0)) > 0:
			var md := float(Data.items[equip["weapon"]["id"]]["dur"])
			equip["weapon"]["dur"] = minf(float(equip["weapon"]["dur"]) + md * float(it["repair"]), md)
			toast("Weapon repaired.", "info")
			used = true
		else:
			toast("Equip a weapon with durability first.", "info")
			return false
	if used:
		Inv.remove(id, 1)
		stats_changed.emit()
	return used


# ------------------------------------------------------------- settings
func load_settings() -> void:
	var s := Save.load_settings()
	for k in SETTINGS_DEFAULT:
		if s.has(k):
			var dv: Variant = SETTINGS_DEFAULT[k]
			if typeof(dv) == TYPE_INT:
				settings[k] = int(s[k])
			elif typeof(dv) == TYPE_FLOAT:
				settings[k] = float(s[k])
			elif typeof(dv) == TYPE_BOOL:
				settings[k] = bool(s[k])
	apply_settings()


func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	apply_settings()
	Save.save_settings(settings)
	settings_changed.emit()


func apply_settings() -> void:
	var fps := int(settings["fps"])
	if bool(settings["perf_mode"]):
		fps = 30
	Engine.max_fps = fps
	var root := get_tree().root
	if root:
		var rs := clampf(float(settings["render_scale"]), 0.5, 1.0)
		if bool(settings["perf_mode"]):
			rs = minf(rs, 0.75)
		root.scaling_3d_scale = rs
	Sfx.apply_volumes()


func quality() -> int:
	if bool(settings["perf_mode"]):
		return 0
	return int(settings["quality"])


# ------------------------------------------------------------- serialization
func serialize() -> Dictionary:
	return {
		"health": health, "stamina": stamina, "hunger": hunger, "temperature": temperature, "heat_ward": heat_ward,
		"level": level, "xp": xp, "skill_points": skill_points, "skills": skills.keys(), "equip": equip,
		"unlocks": unlocks.keys(), "logs": logs_read.keys(), "sites": sites_found.keys(), "regions": regions_seen.keys(),
		"bosses": bosses_defeated.keys(), "opened": opened, "flags": flags, "stats": stats,
		"waypoint": [waypoint.x, waypoint.y] if waypoint != null else [],
		"respawn": [respawn_pos.x, respawn_pos.y, respawn_pos.z], "death_cache": death_cache,
		"day": day_count, "tod": time_of_day, "play_seconds": play_seconds,
		"explored": Marshalls.raw_to_base64(explored),
	}


func _keys_to_dict(arr: Variant) -> Dictionary:
	var d := {}
	if typeof(arr) == TYPE_ARRAY:
		for k in arr:
			d[str(k)] = true
	return d


func deserialize(d: Dictionary) -> void:
	reset_progress()
	level = clampi(int(d.get("level", 1)), 1, MAX_LEVEL)
	xp = maxi(int(d.get("xp", 0)), 0)
	skill_points = maxi(int(d.get("skill_points", 0)), 0)
	skills = _keys_to_dict(d.get("skills", []))
	for k in skills.keys():
		if not Data.skills.has(k):
			skills.erase(k)
	equip = {}
	var eq: Dictionary = d.get("equip", {})
	for slot in eq:
		var e: Dictionary = eq[slot]
		if Data.items.has(str(e.get("id", ""))):
			equip[str(slot)] = {"id": str(e["id"]), "dur": float(e.get("dur", 0.0))}
	recompute_limits()
	health = clampf(float(d.get("health", max_health)), 1.0, max_health)
	stamina = clampf(float(d.get("stamina", 100.0)), 0.0, 100.0)
	hunger = clampf(float(d.get("hunger", 100.0)), 0.0, 100.0)
	temperature = clampf(float(d.get("temperature", 50.0)), 0.0, 100.0)
	heat_ward = maxf(float(d.get("heat_ward", 0.0)), 0.0)
	unlocks = _keys_to_dict(d.get("unlocks", []))
	logs_read = _keys_to_dict(d.get("logs", []))
	sites_found = _keys_to_dict(d.get("sites", []))
	regions_seen = _keys_to_dict(d.get("regions", []))
	bosses_defeated = _keys_to_dict(d.get("bosses", []))
	opened = {}
	var od: Dictionary = d.get("opened", {})
	for k in od:
		opened[str(k)] = int(od[k])
	flags = d.get("flags", {}).duplicate()
	stats = {}
	var sd: Dictionary = d.get("stats", {})
	for k in sd:
		stats[str(k)] = int(sd[k])
	var wp: Array = d.get("waypoint", [])
	waypoint = Vector2(float(wp[0]), float(wp[1])) if wp.size() == 2 else null
	var rp: Array = d.get("respawn", [])
	if rp.size() == 3:
		respawn_pos = Vector3(float(rp[0]), float(rp[1]), float(rp[2]))
	death_cache = d.get("death_cache", {}).duplicate(true)
	day_count = maxi(int(d.get("day", 1)), 1)
	time_of_day = clampf(float(d.get("tod", 0.32)), 0.0, 1.0)
	play_seconds = maxf(float(d.get("play_seconds", 0.0)), 0.0)
	var ex: PackedByteArray = Marshalls.base64_to_raw(str(d.get("explored", "")))
	if ex.size() == EXPLORE_N * EXPLORE_N:
		explored = ex
