extends Node
## Global game state: settings, the active save's progression, derived stats and events.
## Presentation lives elsewhere; this node only holds data and emits signals.

enum State { TITLE, PLAY, PAUSE, DIALOGUE, CUTSCENE, MENU, GAMEOVER }

signal state_changed(s: int)
signal stats_changed
signal progress_changed
signal toast(text: String, kind: String)
signal quest_changed
signal boss_changed(visible: bool, name: String, frac: float)
signal enemy_killed(kind: String)
signal event(id: String)

const SAVE_VERSION := 1

const SETTINGS_DEFAULT := {
	"master": 1.0, "music": 0.7, "sfx": 0.9, "mute": false,
	"shake": true, "flash_reduce": false, "particles": 2,      # 0 off/minimal, 1 reduced, 2 full
	"ui_scale": 1.0, "ctrl_scale": 1.0, "ctrl_opacity": 0.75, "left_handed": false,
	"difficulty": 1, "text_size": 1, "vibration": true, "high_contrast": false, "hints": true,
	"quality": 1,
}

var state: int = State.TITLE
var _state_stack: Array = []
var settings: Dictionary = SETTINGS_DEFAULT.duplicate(true)

# ---- progression (saved)
var slot: int = 0
var region_unlocked: int = 1          # number of regions reachable (1..7)
var bosses: Dictionary = {}           # boss id -> true
var abilities: Dictionary = {}        # dash, wall_jump, double_jump, stasis
var fragments: int = 0
var shards: int = 0
var dust: int = 0                     # upgrade material
var xp: int = 0
var level: int = 1
var skill_points: int = 0
var skills: Dictionary = {}           # id -> level
var owned: Dictionary = {}            # equipment id -> true
var equipped: Dictionary = {}         # slot -> equipment id
var quests: Dictionary = {}           # quest id -> "active" | "done"
var quest_progress: Dictionary = {}   # quest id -> int
var flags: Dictionary = {}            # misc one-time flags (switches, shortcuts, collected items, chests, journals)
var checkpoint: Dictionary = {"region": "meadows", "level": "meadows_1", "id": "start"}
var play_time: float = 0.0
var completed: bool = false
var seen_intro: bool = false
var seen_cutscenes: Dictionary = {}
var deaths: int = 0
var heart_pieces: int = 0
var bonus_hp: int = 0

# ---- runtime (not saved)
var hp: float = 100.0
var mp: float = 60.0
var heals_left: int = 3
var in_boss_fight: bool = false
var god: bool = false                # test hook: no damage to the player


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().set_auto_accept_quit(false)
	_setup_input()
	new_progress()
	settings = Save.load_settings(SETTINGS_DEFAULT)
	enemy_killed.connect(Quests.on_kill)
	event.connect(Quests.on_event)


func _setup_input() -> void:
	var map := {
		"left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT], "up": [KEY_W, KEY_UP], "down": [KEY_S, KEY_DOWN],
		"jump": [KEY_SPACE, KEY_K], "light": [KEY_J, KEY_Z], "heavy": [KEY_L, KEY_X], "dodge": [KEY_SHIFT, KEY_C],
		"magic": [KEY_I, KEY_V], "ability": [KEY_O, KEY_B], "interact": [KEY_E, KEY_ENTER], "heal": [KEY_H, KEY_Q],
		"pause": [KEY_ESCAPE, KEY_P], "map": [KEY_M, KEY_TAB],
	}
	for a in map:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		for k in map[a]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(a, ev)
	var pad := {"jump": JOY_BUTTON_A, "light": JOY_BUTTON_X, "heavy": JOY_BUTTON_Y, "dodge": JOY_BUTTON_B,
		"magic": JOY_BUTTON_RIGHT_SHOULDER, "ability": JOY_BUTTON_LEFT_SHOULDER, "interact": JOY_BUTTON_A,
		"heal": JOY_BUTTON_DPAD_DOWN, "pause": JOY_BUTTON_START, "map": JOY_BUTTON_BACK}
	for a in pad:
		var ev := InputEventJoypadButton.new()
		ev.button_index = pad[a]
		InputMap.action_add_event(a, ev)
	var axes := {"left": [JOY_AXIS_LEFT_X, -1.0], "right": [JOY_AXIS_LEFT_X, 1.0], "up": [JOY_AXIS_LEFT_Y, -1.0], "down": [JOY_AXIS_LEFT_Y, 1.0]}
	for a in axes:
		var ev := InputEventJoypadMotion.new()
		ev.axis = axes[a][0]
		ev.axis_value = axes[a][1]
		InputMap.action_add_event(a, ev)


# ------------------------------------------------------------- state machine
func set_state(s: int) -> void:
	if s == state:
		return
	state = s
	get_tree().paused = s in [State.PAUSE, State.DIALOGUE, State.MENU, State.CUTSCENE, State.GAMEOVER, State.TITLE]
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
	return state == State.PLAY


# ------------------------------------------------------------- new / derived stats
func new_progress() -> void:
	region_unlocked = 1
	bosses = {}
	abilities = {}
	fragments = 0
	shards = 0
	dust = 0
	xp = 0
	level = 1
	skill_points = 0
	skills = {}
	owned = {}
	equipped = {}
	quests = {}
	quest_progress = {}
	flags = {}
	checkpoint = {"region": "meadows", "level": "meadows_1", "id": "start"}
	play_time = 0.0
	completed = false
	seen_intro = false
	seen_cutscenes = {}
	deaths = 0
	heart_pieces = 0
	bonus_hp = 0
	in_boss_fight = false
	_state_stack.clear()
	full_restore()


func skill(id: String) -> int:
	return int(skills.get(id, 0))


func equip_stat(key: String) -> float:
	var t := 0.0
	for slot_name in equipped:
		var eid: String = equipped[slot_name]
		if Defs.EQUIPMENT.has(eid):
			t += float(Defs.EQUIPMENT[eid]["stats"].get(key, 0.0))
	return t


func max_hp() -> float:
	return 100.0 + 20.0 * skill("vitality") + (10.0 * fragments) + float(bonus_hp)


func max_mp() -> float:
	return 60.0 + 15.0 * skill("aether") + (5.0 * fragments)


func heal_amount() -> float:
	return 45.0 + 12.0 * skill("mending")


func max_heals() -> int:
	return maxi(3 + int(Defs.DIFFICULTY[settings["difficulty"]]["heals"]), 1)


func light_mult() -> float:
	return 1.0 + 0.12 * skill("edge") + 0.05 * fragments


func heavy_mult() -> float:
	return 1.0 + 0.15 * skill("crusher") + equip_stat("heavy") + 0.05 * fragments


func mp_regen() -> float:
	return 4.5 * (1.0 + 0.15 * skill("focus"))


func magic_cost(base: float) -> float:
	return base * (1.0 - equip_stat("magic_cost"))


func shard_mult() -> float:
	return 1.0 + 0.15 * skill("gatherer")


func dash_cooldown() -> float:
	return Tune.DASH_COOLDOWN * (1.0 - 0.12 * skill("windstep")) * (1.0 - equip_stat("dash_cd"))


func difficulty() -> Dictionary:
	return Defs.DIFFICULTY[int(settings["difficulty"])]


func full_restore() -> void:
	hp = max_hp()
	mp = max_mp()
	heals_left = max_heals()
	stats_changed.emit()


func has_ability(id: String) -> bool:
	return abilities.has(id)


func unlock_ability(id: String) -> void:
	if abilities.has(id):
		return
	abilities[id] = true
	toast.emit("Ability unlocked: " + ABILITY_NAMES.get(id, id), "ability")
	progress_changed.emit()


const ABILITY_NAMES := {"dash": "Starlight Dash", "wall_jump": "Wall Jump", "double_jump": "Skyleap", "stasis": "Stasis Pulse"}


# ------------------------------------------------------------- economy
func add_shards(n: int) -> void:
	shards += n
	if n > 0:
		Quests.on_shards(n)
	stats_changed.emit()


func add_xp(n: int) -> void:
	xp += n
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		skill_points += 1
		toast.emit("Level %d! You earned a skill point." % level, "level")
	stats_changed.emit()


func xp_needed() -> int:
	return 60 + level * 40


func can_buy_skill(id: String) -> String:
	if not Defs.SKILLS.has(id):
		return "Unknown skill."
	var s: Dictionary = Defs.SKILLS[id]
	if skill(id) >= int(s["max"]):
		return "Maxed."
	if skill_points < int(s["cost"]):
		return "Needs %d skill point(s)." % int(s["cost"])
	return ""


func buy_skill(id: String) -> bool:
	if can_buy_skill(id) != "":
		return false
	skill_points -= int(Defs.SKILLS[id]["cost"])
	skills[id] = skill(id) + 1
	if id == "vitality":
		hp = minf(hp + 20.0, max_hp())
	if id == "aether":
		mp = minf(mp + 15.0, max_mp())
	stats_changed.emit()
	progress_changed.emit()
	return true


func give_equipment(id: String) -> void:
	if owned.has(id) or not Defs.EQUIPMENT.has(id):
		return
	owned[id] = true
	var sl: String = Defs.EQUIPMENT[id]["slot"]
	if not equipped.has(sl):
		equipped[sl] = id
	toast.emit("Found: " + Defs.EQUIPMENT[id]["name"], "item")
	progress_changed.emit()


func equip(id: String) -> void:
	if not owned.has(id):
		return
	equipped[Defs.EQUIPMENT[id]["slot"]] = id
	stats_changed.emit()
	progress_changed.emit()


func unequip(slot_name: String) -> void:
	equipped.erase(slot_name)
	stats_changed.emit()
	progress_changed.emit()


# ------------------------------------------------------------- flags
func flag(key: String) -> bool:
	return bool(flags.get(key, false))


func set_flag(key: String, v: bool = true) -> void:
	flags[key] = v


# ------------------------------------------------------------- save data
func serialize() -> Dictionary:
	return {
		"slot": slot, "region_unlocked": region_unlocked, "bosses": bosses.keys(), "abilities": abilities.keys(),
		"fragments": fragments, "shards": shards, "dust": dust, "xp": xp, "level": level, "skill_points": skill_points,
		"skills": skills, "owned": owned.keys(), "equipped": equipped, "quests": quests, "quest_progress": quest_progress,
		"flags": flags, "checkpoint": checkpoint, "play_time": play_time, "completed": completed, "seen_intro": seen_intro,
		"seen_cutscenes": seen_cutscenes.keys(), "deaths": deaths, "heart_pieces": heart_pieces, "bonus_hp": bonus_hp,
	}


func deserialize(d: Dictionary) -> void:
	new_progress()
	region_unlocked = clampi(int(d.get("region_unlocked", 1)), 1, 7)
	bosses = _keys(d.get("bosses", []))
	abilities = _keys(d.get("abilities", []))
	fragments = clampi(int(d.get("fragments", 0)), 0, 7)
	shards = maxi(int(d.get("shards", 0)), 0)
	dust = maxi(int(d.get("dust", 0)), 0)
	xp = maxi(int(d.get("xp", 0)), 0)
	level = maxi(int(d.get("level", 1)), 1)
	skill_points = maxi(int(d.get("skill_points", 0)), 0)
	skills = {}
	for k in d.get("skills", {}):
		if Defs.SKILLS.has(k):
			skills[k] = clampi(int(d["skills"][k]), 0, int(Defs.SKILLS[k]["max"]))
	owned = {}
	for k in d.get("owned", []):
		if Defs.EQUIPMENT.has(k):
			owned[k] = true
	equipped = {}
	for k in d.get("equipped", {}):
		var eid: String = str(d["equipped"][k])
		if owned.has(eid):
			equipped[k] = eid
	quests = d.get("quests", {}).duplicate()
	quest_progress = d.get("quest_progress", {}).duplicate()
	flags = d.get("flags", {}).duplicate()
	var cp: Variant = d.get("checkpoint", null)
	if cp is Dictionary and cp.has("level"):
		checkpoint = cp
	play_time = float(d.get("play_time", 0.0))
	completed = bool(d.get("completed", false))
	seen_intro = bool(d.get("seen_intro", false))
	seen_cutscenes = _keys(d.get("seen_cutscenes", []))
	deaths = int(d.get("deaths", 0))
	heart_pieces = clampi(int(d.get("heart_pieces", 0)), 0, 60)
	bonus_hp = clampi(int(d.get("bonus_hp", 0)), 0, 200)
	full_restore()


func _keys(arr: Variant) -> Dictionary:
	var out := {}
	if arr is Array:
		for k in arr:
			out[str(k)] = true
	return out


func apply_setting(key: String, value: Variant) -> void:
	settings[key] = value
	Save.save_settings(settings)
	if key in ["master", "music", "sfx", "mute"]:
		Sfx.apply_volumes()
	state_changed.emit(state)


func _process(delta: float) -> void:
	if state == State.PLAY:
		play_time += delta
