class_name LevelGen
extends RefCounted
## Deterministic room generator. Each region is a chain of rooms (hub, runs, a vertical climb, a puzzle room, a pre-boss
## sanctuary and the boss arena). Rooms are assembled from segment templates that respect the movement limits in Tune,
## and tests verify every room with Verifier (a conservative reachability model) before it can ship.

const PLAN := {
	"meadows": ["hub", "run", "vert", "puzzle_seq", "run", "pre"],
	"ember": ["hub", "run", "vert", "puzzle_block", "run", "pre"],
	"observatory": ["hub", "run", "vert", "puzzle_beam", "run", "pre"],
	"thornwild": ["hub", "run", "puzzle_block", "vert", "run", "pre"],
	"frostfall": ["hub", "run", "vert", "puzzle_seq", "run", "pre"],
	"clockwork": ["hub", "run", "puzzle_beam", "vert", "run", "pre"],
	"eclipse": ["hub", "run", "vert", "puzzle_mixed", "run", "pre"],
}

const ROOM_TITLES := {
	"meadows": ["Sunlit Landing", "Windy Crossing", "The Stair of Birds", "Hall of Beacons", "Bridge of Sighs", "Colossus Gate"],
	"ember": ["Cinder Gate", "River of Slag", "Chimney Climb", "Slab and Plate", "Crusher Row", "Furnace Door"],
	"observatory": ["Drowned Foyer", "Flooded Gallery", "The Long Shaft", "Hall of Prisms", "Reflecting Pools", "Eye Chamber Door"],
	"thornwild": ["Rootgate", "Bramble Trail", "Spore Hollow", "The Climbing Roots", "Thorn Gauntlet", "Queen's Threshold"],
	"frostfall": ["Frozen Gate", "Ice Bridge", "Spire Ascent", "Hall of Frost Beacons", "Whiteout Walk", "Throne Approach"],
	"clockwork": ["Cogworks Entry", "Escapement Run", "Gear Hall of Prisms", "The Chain Lift", "Laser Foundry", "Sovereign's Gate"],
	"eclipse": ["Black Shore", "Fractured Nave", "The Falling Stair", "Hall of Echoes", "Shattered Aisle", "Architect's Door"],
}

const HUB_NPCS := {
	"meadows": ["merchant", "warrior", "scholar"], "ember": ["inventor"], "observatory": ["scholar"],
	"thornwild": ["merchant"], "frostfall": ["warrior"], "clockwork": ["inventor", "merchant"], "eclipse": ["scholar", "warrior"],
}

const ENEMIES := {
	"meadows": ["slime", "slime", "guard"], "ember": ["crawler", "crawler", "guard", "slime"],
	"observatory": ["archer", "guard", "slime"], "thornwild": ["stalker", "stalker", "slime", "archer"],
	"frostfall": ["knight", "archer", "guard", "archer"], "clockwork": ["drone", "drone", "knight", "guard", "archer"],
	"eclipse": ["wraith", "wraith", "knight", "drone", "stalker", "crawler"],
}

# abilities the player is guaranteed to own when they reach each region (granted by earlier bosses)
const REGION_ABILITIES := {
	"meadows": [], "ember": ["dash"], "observatory": ["dash", "wall_jump"], "thornwild": ["dash", "wall_jump", "stasis"],
	"frostfall": ["dash", "wall_jump", "stasis", "double_jump"], "clockwork": ["dash", "wall_jump", "stasis", "double_jump"],
	"eclipse": ["dash", "wall_jump", "stasis", "double_jump"],
}

const EQUIP_SECRETS := {
	"meadows": "windrunner_boots", "ember": "ember_charm", "observatory": "astral_lens", "thornwild": "thorn_veil",
	"frostfall": "frost_band", "clockwork": "gearwright_gloves", "eclipse": "eclipse_mantle",
}

const JOURNAL_IDS := {
	"meadows": ["meadows_a", "meadows_b"], "ember": ["ember_a", "ember_b"], "observatory": ["obs_a", "obs_b"],
	"thornwild": ["thorn_a", "thorn_b"], "frostfall": ["frost_a", "frost_b"], "clockwork": ["clock_a", "clock_b"], "eclipse": ["eclipse_a", "eclipse_b"],
}


static func room_ids(region: String) -> Array:
	var out: Array = []
	for i in PLAN[region].size():
		out.append("%s_%d" % [region, i + 1])
	out.append(region + "_boss")
	return out


static func all_room_ids() -> Array:
	var out: Array = []
	for r in Defs.REGION_ORDER:
		out.append_array(room_ids(r))
	return out


static func next_of(id: String) -> Array:
	# returns [next_room_id, entry]; "" when the campaign ends
	var parts := id.rsplit("_", true, 1)
	var region: String = parts[0]
	var n: int = PLAN[region].size()
	if parts[1] == "boss":
		var ri := Defs.REGION_ORDER.find(region)
		if ri + 1 < Defs.REGION_ORDER.size():
			return [Defs.REGION_ORDER[ri + 1] + "_1", "from_prev"]
		return ["", ""]
	var i := int(parts[1])
	if i >= n:
		return [region + "_boss", "from_prev"]
	return ["%s_%d" % [region, i + 1], "from_prev"]


static func prev_of(id: String) -> Array:
	var parts := id.rsplit("_", true, 1)
	var region: String = parts[0]
	var n: int = PLAN[region].size()
	if parts[1] == "boss":
		return ["%s_%d" % [region, n], "from_next"]
	var i := int(parts[1])
	if i <= 1:
		var ri := Defs.REGION_ORDER.find(region)
		if ri == 0:
			return ["", ""]
		return [Defs.REGION_ORDER[ri - 1] + "_boss", "from_next"]
	return ["%s_%d" % [region, i - 1], "from_next"]


static func build(id: String) -> LevelData:
	var parts := id.rsplit("_", true, 1)
	if parts.size() != 2 or not Defs.REGIONS.has(parts[0]):
		return null
	var region: String = parts[0]
	var plan: Array = PLAN[region]
	var is_boss: bool = parts[1] == "boss"
	var idx := plan.size() + 1 if is_boss else int(parts[1])
	if not is_boss and (idx < 1 or idx > plan.size()):
		return null
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id) ^ 0x5F3759DF
	var kind: String = "boss" if is_boss else plan[idx - 1]
	var cv: Cv
	var ctx := {"region": region, "idx": idx, "rng": rng, "id": id, "kind": kind}
	match kind:
		"hub": cv = _room_hub(ctx)
		"run": cv = _room_run(ctx)
		"vert": cv = _room_vert(ctx)
		"pre": cv = _room_pre(ctx)
		"boss": cv = _room_boss(ctx)
		_: cv = _room_puzzle(ctx)
	var d := LevelData.new()
	d.id = id
	d.region = region
	d.title = "%s: %s" % [Defs.REGIONS[region]["name"], ("Guardian Arena" if is_boss else ROOM_TITLES[region][idx - 1])]
	d.rows = cv.to_rows()
	d.is_boss_arena = is_boss
	d.boss_id = Defs.REGIONS[region]["boss"] if is_boss else ""
	d.music = ("boss" if is_boss else Defs.REGIONS[region]["music"])
	d.meta = {"spawns": cv.spawns, "entities": cv.entities, "puzzles": cv.puzzles, "kind": kind, "abilities": REGION_ABILITIES[region]}
	for k in cv.meta:
		d.meta[k] = cv.meta[k]
	d.finalize()
	return d


# =============================================================== helpers
static func _fill_ground(cv: Cv, x0: int, x1: int, fy: int, region: String) -> void:
	for x in range(x0, x1 + 1):
		for y in range(fy, cv.h):
			cv.set_c(x, y, "#")
		if region == "frostfall" and fy < cv.h - 2:
			cv.set_c(x, fy, "I")


static func _walls(cv: Cv, ceiling: bool, region: String) -> void:
	for y in cv.h:
		cv.set_c(0, y, "#")
		cv.set_c(cv.w - 1, y, "#")
	if ceiling:
		for x in cv.w:
			cv.set_c(x, 0, "#")
			cv.set_c(x, 1, "#")


static func _has_ceiling(region: String) -> bool:
	return region in ["ember", "observatory", "clockwork"]


static func _pit_floor(cv: Cv, x0: int, x1: int, region: String, depth_row: int) -> void:
	# bottom of a pit: hazard layer. Falling hurts a little and returns Kael to the last safe ground.
	var hz := "^"
	var thick := 1
	match region:
		"ember": hz = "L"; thick = 2
		"observatory": hz = "^"
		"thornwild": hz = "T"
		"eclipse": hz = "^"
	for x in range(x0, x1 + 1):
		cv.set_c(x, cv.h - 1, "#")
		for k in thick:
			cv.set_c(x, cv.h - 2 - k, hz)


static func _span(cv: Cv, x0: int, x1: int, y: int) -> void:
	cv.spans.append({"x0": x0, "x1": x1, "y": y})


static func _exit(cv: Cv, x: int, fy: int, to: String, entry: String, extra: Dictionary = {}) -> void:
	var e := {"t": "i", "kind": "exit", "x": x, "y": fy - 1, "to": to, "entry": entry, "w": 1, "h": 4, "mode": "touch"}
	for k in extra:
		e[k] = extra[k]
	cv.ent(e)


# =============================================================== hub
static func _room_hub(ctx: Dictionary) -> Cv:
	var region: String = ctx["region"]
	var rng: RandomNumberGenerator = ctx["rng"]
	var cv := Cv.new(60, 24)
	var fy := 19
	_walls(cv, _has_ceiling(region), region)
	_fill_ground(cv, 0, cv.w - 1, fy, region)
	cv.spawns["start"] = [4, fy - 1]
	cv.spawns["from_prev"] = [4, fy - 1]
	cv.spawns["from_next"] = [cv.w - 5, fy - 1]
	var pv: Array = prev_of(ctx["id"])
	if pv[0] != "":
		_exit(cv, 0, fy, pv[0], pv[1])
	var nx: Array = next_of(ctx["id"])
	_exit(cv, cv.w - 1, fy, nx[0], nx[1])
	_span(cv, 2, cv.w - 3, fy)
	# the starshrine
	cv.ent({"t": "i", "kind": "checkpoint", "x": 7, "y": fy - 1, "id": "start"})
	# npcs
	var npcs: Array = HUB_NPCS[region]
	for i in npcs.size():
		cv.ent({"t": "i", "kind": "npc", "x": 14 + i * 4, "y": fy - 1, "npc": npcs[i]})
	# decor platforms (ruined bridge pieces) and a reachable chest
	cv.fill(22, fy - 3, 26, fy - 3, "=")
	cv.fill(29, fy - 5, 33, fy - 5, "=")
	cv.fill(36, fy - 3, 40, fy - 3, "=")
	cv.ent({"t": "i", "kind": "chest", "x": 31, "y": fy - 6, "id": "hub_a", "item": {"shards": 30 + 10 * int(ctx["idx"])}})
	cv.ent({"t": "i", "kind": "journal", "x": 45, "y": fy - 1, "id": "j1", "entry": JOURNAL_IDS[region][0]})
	var hints: Array = Story.HINTS[region]
	cv.ent({"t": "i", "kind": "hint", "x": 10, "y": fy - 1, "id": "h1", "text": hints[0]})
	# a few gentle enemies near the far side
	_place_enemies(cv, ctx, 2, 40, 54)
	# shortcut door back from the pre-boss sanctuary: opens once its lever is pulled
	cv.ent({"t": "i", "kind": "exit", "x": cv.w - 9, "y": fy - 1, "to": "%s_6" % region, "entry": "from_shortcut", "w": 1, "h": 3, "mode": "interact",
		"requires": "puzzle_%s_5_shortcut" % region, "locked_msg": "A heavy gate. It will only open from the other side.", "visible": true})
	return cv


# =============================================================== enemies and items
static func _place_enemies(cv: Cv, ctx: Dictionary, n: int, x_min: int, x_max: int) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var region: String = ctx["region"]
	var pool: Array = ENEMIES[region]
	var spans: Array = []
	for s in cv.spans:
		if int(s["x1"]) - int(s["x0"]) >= 5 and int(s["x1"]) > x_min and int(s["x0"]) < x_max:
			spans.append(s)
	if spans.is_empty():
		return
	var tier := clampi(int(ctx["idx"]) - 1, 0, 6)
	for i in n:
		var s: Dictionary = spans[rng.randi() % spans.size()]
		var lo := maxi(int(s["x0"]) + 1, x_min)
		var hi := mini(int(s["x1"]) - 1, x_max)
		if hi <= lo:
			continue
		var x := rng.randi_range(lo, hi)
		var k: String = pool[rng.randi() % pool.size()]
		var y: int = int(s["y"]) - 1
		if k == "drone" or k == "wraith":
			y -= rng.randi_range(2, 4)
		cv.ent({"t": "enemy", "k": k, "x": x, "y": y, "patrol": 90.0 + 12.0 * tier})


static func _place_items(cv: Cv, ctx: Dictionary, chests: int, journals: int, shrines: int) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var region: String = ctx["region"]
	var spans: Array = []
	for s in cv.spans:
		if int(s["x1"]) - int(s["x0"]) >= 6:
			spans.append(s)
	if spans.is_empty():
		return
	var idx: int = ctx["idx"]
	for i in shrines:
		var s: Dictionary = spans[(spans.size() / 2 + i) % spans.size()]
		var x := (int(s["x0"]) + int(s["x1"])) / 2
		cv.ent({"t": "i", "kind": "checkpoint", "x": x, "y": int(s["y"]) - 1, "id": "mid%d" % i})
	for i in chests:
		var s: Dictionary = spans[rng.randi() % spans.size()]
		var x := rng.randi_range(int(s["x0"]) + 1, int(s["x1"]) - 1)
		var item: Dictionary
		var roll := rng.randf()
		if roll < 0.5:
			item = {"shards": 25 + 15 * idx + rng.randi_range(0, 20)}
		elif roll < 0.8:
			item = {"dust": 3 + idx + rng.randi_range(0, 3)}
		elif roll < 0.92:
			item = {"heart": 1}
		else:
			item = {"skill_point": 1}
		cv.ent({"t": "i", "kind": "chest", "x": x, "y": int(s["y"]) - 1, "id": "c%d" % i, "item": item})
	var js: Array = JOURNAL_IDS[region]
	for i in journals:
		var s: Dictionary = spans[rng.randi() % spans.size()]
		var x := rng.randi_range(int(s["x0"]) + 1, int(s["x1"]) - 1)
		cv.ent({"t": "i", "kind": "journal", "x": x, "y": int(s["y"]) - 1, "id": "j%d" % i, "entry": js[1 if idx >= 3 else 0]})


# =============================================================== horizontal run rooms
const SEG_WEIGHTS := {
	"meadows": ["flat", "gap", "gap", "step", "platforms", "mound", "spikes", "tower", "pool", "flat"],
	"ember": ["flat", "gap_lava", "gap_lava", "step", "platforms", "moving", "spikes", "tower", "crusher", "gap_dash"],
	"observatory": ["flat", "gap", "pool", "pool", "step", "platforms", "tower", "spikes", "mound"],
	"thornwild": ["flat", "gap", "step", "platforms", "thorns", "thorns", "tower", "mound", "spikes"],
	"frostfall": ["flat", "gap", "gap", "step", "platforms", "spikes", "tower", "mound", "gap_dash", "saw"],
	"clockwork": ["flat", "moving", "moving", "crusher", "crusher", "laser", "saw", "platforms", "tower", "gap_dash", "step"],
	"eclipse": ["flat", "gap_dash", "gap_dash", "moving", "laser", "saw", "platforms", "tower", "crusher", "step", "spikes"],
}


static func _room_run(ctx: Dictionary) -> Cv:
	var region: String = ctx["region"]
	var idx: int = ctx["idx"]
	var rng: RandomNumberGenerator = ctx["rng"]
	var w := 118 + 6 * idx + rng.randi_range(0, 8)
	var cv := Cv.new(w, 26)
	_walls(cv, _has_ceiling(region), region)
	var st := {"cv": cv, "x": 0, "fy": 19, "region": region, "rng": rng, "idx": idx, "last": "", "secret": false, "ctx": ctx}
	var fy: int = st["fy"]
	_fill_ground(cv, 0, 8, fy, region)
	_span(cv, 2, 8, fy)
	st["x"] = 9
	cv.spawns["start"] = [3, fy - 1]
	cv.spawns["from_prev"] = [3, fy - 1]
	var pv: Array = prev_of(ctx["id"])
	_exit(cv, 0, fy, pv[0], pv[1])
	var weights: Array = SEG_WEIGHTS[region]
	var guard := 0
	var count := 0
	while int(st["x"]) < w - 34 and guard < 80:
		guard += 1
		var pick: String = weights[rng.randi() % weights.size()]
		# the equipment secret appears in the second room of each region (and a second one in room 5)
		if not st["secret"] and int(st["x"]) > 30 and (idx == 2 or idx == 5):
			pick = "secret_pit"
		if pick == "gap_dash" and (idx < 2 and region == "meadows"):
			pick = "gap"
		_run_segment(st, pick)
		count += 1
	# final flat run-out and exit
	fy = st["fy"]
	var xs: int = st["x"]
	_fill_ground(cv, xs, w - 1, fy, region)
	_span(cv, xs, w - 3, fy)
	var nx: Array = next_of(ctx["id"])
	_exit(cv, w - 1, fy, nx[0], nx[1])
	cv.spawns["from_next"] = [w - 4, fy - 1]
	# lever that opens the shortcut door back to the hub (room 5 only)
	if idx == 5:
		cv.ent({"t": "i", "kind": "switch", "x": w - 8, "y": fy - 1, "group": "shortcut", "mode": "hit"})
		cv.puzzles["shortcut"] = {"kind": "all", "count": 1, "gates": []}
	_place_enemies(cv, ctx, 3 + idx * 2, 14, w - 12)
	_place_items(cv, ctx, 2, 1, 1)
	if idx == 2:
		var hints: Array = Story.HINTS[region]
		cv.ent({"t": "i", "kind": "hint", "x": 11, "y": 18, "id": "h2", "text": hints[1 % hints.size()]})
	return cv


static func _run_segment(st: Dictionary, name: String) -> void:
	var cv: Cv = st["cv"]
	var rng: RandomNumberGenerator = st["rng"]
	var region: String = st["region"]
	var fy: int = st["fy"]
	var x: int = st["x"]
	var needs_runup := name in ["gap", "gap_lava", "gap_dash", "platforms", "moving", "pool", "tower", "secret_pit"]
	if needs_runup and st["last"] != "flat":
		_ground_run(st, 3)
		x = st["x"]
	match name:
		"flat":
			_ground_run(st, rng.randi_range(5, 10))
		"gap", "gap_lava":
			var gw := rng.randi_range(2, 4)
			if name == "gap_lava":
				gw = rng.randi_range(3, 4)
			for i in gw:
				pass
			_pit_floor(cv, x, x + gw - 1, region, cv.h - 3)
			st["x"] = x + gw
			_ground_run(st, 3)
		"gap_dash":
			var gw2 := 6
			_pit_floor(cv, x, x + gw2 - 1, region, cv.h - 3)
			cv.meta["needs_dash"] = true
			st["x"] = x + gw2
			_ground_run(st, 3)
		"step":
			var dy: int = [-3, -2, -1, 1, 2][rng.randi() % 5]
			var nfy := clampi(fy + dy, 9, 21)
			st["fy"] = nfy
			_ground_run(st, rng.randi_range(4, 7))
		"mound":
			st["fy"] = fy - 2
			_ground_run(st, 4)
			st["fy"] = fy
			_ground_run(st, 3)
		"platforms":
			var n := rng.randi_range(3, 4)
			var total := n * 5 + 2
			_pit_floor(cv, x, x + total - 1, region, cv.h - 3)
			var py := fy
			for i in n:
				var px := x + 1 + i * 5
				var ny := clampi(py - rng.randi_range(0, 2) + (1 if rng.randf() < 0.4 else 0), fy - 2, fy + 1)
				if i == 0 or i == n - 1:
					ny = fy - 1
				py = ny
				cv.fill(px, py, px + 2, py, "=")
				if i % 2 == 1 and rng.randf() < 0.5:
					_span(cv, px, px + 2, py)
			st["x"] = x + total
			_ground_run(st, 3)
		"spikes":
			_ground_run(st, 3)
			x = st["x"]
			var n2 := rng.randi_range(2, 4)
			var hz := "T" if region == "thornwild" else "^"
			for i in n2:
				cv.set_c(x + i, st["fy"] - 1, hz)
			_fill_ground(cv, x, x + n2 + 1, st["fy"], region)
			st["x"] = x + n2
			_ground_run(st, 3)
		"thorns":
			_ground_run(st, 3)
			x = st["x"]
			var n3 := rng.randi_range(3, 4)
			for i in n3:
				cv.set_c(x + i, st["fy"] - 1, "T")
				if i % 2 == 0:
					cv.set_c(x + i, st["fy"] - 2, "T")
			_fill_ground(cv, x, x + n3 + 1, st["fy"], region)
			st["x"] = x + n3
			_ground_run(st, 3)
		"tower":
			# a wall five tiles tall with a ladder up its left face
			_ground_run(st, 2)
			x = st["x"]
			var hgt := 5
			_fill_ground(cv, x, x + 3, fy - hgt, region)
			for yy in range(fy - hgt - 1, fy):
				cv.set_c(x - 1, yy, "H")
				cv.set_c(x + 4, yy, "H")
			cv.fill(x, fy - hgt, x + 1, fy - hgt, "#")
			for xx in range(x, x + 2):
				cv.fill(xx, fy - hgt, xx, cv.h - 1, "#")
			# ground left of the ladder base is the previous run; right side drops back to the floor level
			_fill_ground(cv, x + 2, x + 3, fy - hgt, region)
			_span(cv, x, x + 3, fy - hgt)
			# the original floor must exist under the tower's far side
			st["x"] = x + 4
			_ground_run(st, 5)
		"pool":
			_ground_run(st, 2)
			x = st["x"]
			var pw := rng.randi_range(5, 7)
			for xx in range(x, x + pw):
				for yy in range(fy, cv.h):
					cv.set_c(xx, yy, "#")
				cv.set_c(xx, fy, "~")
				cv.set_c(xx, fy + 1, "~")
				for yy in range(fy + 3, cv.h):
					cv.set_c(xx, yy, "#")
				cv.set_c(xx, fy + 2, "#")
			st["x"] = x + pw
			_ground_run(st, 3)
		"moving":
			var gw3 := rng.randi_range(8, 10)
			_pit_floor(cv, x, x + gw3 - 1, region, cv.h - 3)
			cv.ent({"t": "platform", "pts": [[x + 1, fy], [x + gw3 - 2, fy]], "speed": 70.0 + 4.0 * float(st["idx"]), "w": 96.0})
			cv.meta["platform_nodes"] = cv.meta.get("platform_nodes", []) + [[x + 1, fy - 1], [x + 2, fy - 1], [x + gw3 - 2, fy - 1], [x + gw3 - 3, fy - 1]]
			st["x"] = x + gw3
			_ground_run(st, 3)
		"crusher":
			_ground_run(st, 2)
			x = st["x"]
			var cl := 12
			_ground_run(st, cl)
			for i in 2:
				var cx := x + 3 + i * 5
				cv.ent({"t": "hazard", "k": "crusher", "px": (cx + 0.5) * 32.0, "py": float(fy) * 32.0 - 96.0 - 56.0, "drop": 96, "period": 3.0 + 0.4 * i, "phase": float(i) * 1.3})
		"laser":
			_ground_run(st, 3)
			x = st["x"]
			_ground_run(st, 9)
			cv.ent({"t": "hazard", "k": "laser", "px": (x + 4.5) * 32.0, "py": float(fy - 5) * 32.0, "len": 160, "vertical": true, "period": 2.6, "phase": rng.randf() * 2.0})
		"saw":
			_ground_run(st, 2)
			x = st["x"]
			_ground_run(st, 12)
			cv.ent({"t": "hazard", "k": "saw", "px": (x + 2.5) * 32.0, "py": float(fy) * 32.0 - 15.0, "speed": 85.0,
				"pts": [[(x + 2.5) * 32.0, float(fy) * 32.0 - 15.0], [(x + 9.5) * 32.0, float(fy) * 32.0 - 15.0]]})
		"secret_pit":
			_secret_pit(st)
	st["last"] = "flat" if name in ["flat", "gap", "gap_lava", "gap_dash", "step", "mound", "platforms", "spikes", "thorns", "tower", "pool", "moving"] else name
	if name in ["flat"]:
		st["last"] = "flat"


static func _ground_run(st: Dictionary, n: int) -> void:
	var cv: Cv = st["cv"]
	var x: int = st["x"]
	var fy: int = st["fy"]
	_fill_ground(cv, x, x + n - 1, fy, st["region"])
	_span(cv, x, x + n - 1, fy)
	st["x"] = x + n
	st["last"] = "flat"


## A pit with a cracked wall in one side. Strike the wall to open a tunnel to a chest.
static func _secret_pit(st: Dictionary) -> void:
	var cv: Cv = st["cv"]
	var fy: int = st["fy"]
	var x: int = st["x"]
	var region: String = st["region"]
	var idx: int = st["idx"]
	var pw := 4
	# pit: floor row fy+3 is solid
	for xx in range(x, x + pw):
		for yy in range(fy, fy + 3):
			cv.set_c(xx, yy, ".")
		for yy in range(fy + 3, cv.h):
			cv.set_c(xx, yy, "#")
	# tunnel behind the right wall
	var tx0 := x + pw
	for xx in range(tx0, tx0 + 8):
		for yy in range(fy, cv.h):
			cv.set_c(xx, yy, "#")
	for xx in range(tx0 + 1, tx0 + 7):
		cv.set_c(xx, fy + 1, ".")
		cv.set_c(xx, fy + 2, ".")
	cv.set_c(tx0, fy + 1, "X")
	cv.set_c(tx0, fy + 2, "X")
	var item: Dictionary = {"shards": 60 + 20 * idx, "dust": 4}
	if idx == 2:
		item = {"equip": EQUIP_SECRETS[region]}
	else:
		item = {"heart": 1}
	cv.ent({"t": "i", "kind": "chest", "x": tx0 + 5, "y": fy + 2, "id": "secret%d" % idx, "item": item})
	cv.meta["secret_cells"] = cv.meta.get("secret_cells", []) + [[x + 1, fy + 2], [tx0 + 5, fy + 2]]
	st["secret"] = true
	st["x"] = tx0 + 8
	st["last"] = "pit"
	_span(cv, tx0 + 8, tx0 + 8, fy)
	_ground_run(st, 3)


# =============================================================== vertical rooms
static func _room_vert(ctx: Dictionary) -> Cv:
	var region: String = ctx["region"]
	if region in ["observatory", "thornwild", "eclipse"]:
		return _vert_shaft(ctx)
	return _vert_hops(ctx)


static func _vert_hops(ctx: Dictionary) -> Cv:
	var region: String = ctx["region"]
	var rng: RandomNumberGenerator = ctx["rng"]
	var idx: int = ctx["idx"]
	var w := 40
	var h := 58
	var cv := Cv.new(w, h)
	_walls(cv, false, region)
	var fy := h - 5
	_fill_ground(cv, 0, w - 1, fy, region)
	cv.spawns["start"] = [3, fy - 1]
	cv.spawns["from_prev"] = [3, fy - 1]
	var pv: Array = prev_of(ctx["id"])
	_exit(cv, 0, fy, pv[0], pv[1])
	_span(cv, 2, 12, fy)
	var top := 8
	var py := fy
	var xi := 0
	var dir := 1
	var n := 0
	var xs: Array = [4, 10, 16, 22, 28]
	while py > top + 4:
		py -= 2
		var px: int = xs[xi]
		cv.fill(px, py, px + 3, py, "=")
		_span(cv, px, px + 3, py)
		if n % 3 == 2:
			cv.set_c(px + 2, py - 1, "^" if region != "thornwild" else "T")
		n += 1
		if n % 4 == 0:
			for yy in range(py - 4, py):
				cv.set_c(px, yy, "H")
		xi += dir
		if xi >= xs.size() or xi < 0:
			dir = -dir
			xi += dir
			xi += dir if false else 0
	# top landing: a full-width one-way walkway so any final hop connects
	cv.fill(2, top, w - 3, top, "=")
	_span(cv, 2, w - 3, top)
	var nx2: Array = next_of(ctx["id"])
	_exit(cv, w - 2, top, nx2[0], nx2[1])
	cv.spawns["from_next"] = [w - 6, top - 1]
	cv.ent({"t": "i", "kind": "checkpoint", "x": w - 10, "y": top - 1, "id": "top"})
	cv.ent({"t": "i", "kind": "chest", "x": w - 15, "y": top - 1, "id": "cv", "item": {"skill_point": 1}})
	_place_enemies(cv, ctx, 4 + idx, 3, w - 3)
	cv.meta["vertical"] = true
	return cv


static func _vert_shaft(ctx: Dictionary) -> Cv:
	var region: String = ctx["region"]
	var rng: RandomNumberGenerator = ctx["rng"]
	var idx: int = ctx["idx"]
	var w := 34
	var h := 62
	var cv := Cv.new(w, h)
	_walls(cv, true, region)
	# solid mass with a 4-wide shaft
	cv.fill(0, 0, w - 1, h - 1, "#")
	var sx0 := 13
	var sx1 := 16
	var floor_y := h - 6
	var top_floor := 10
	# bottom chamber
	cv.fill(1, floor_y - 6, w - 2, floor_y - 1, ".")
	# shaft
	cv.fill(sx0, top_floor - 6, sx1, floor_y - 1, ".")
	# top chamber (right side)
	cv.fill(sx0, top_floor - 6, w - 2, top_floor - 1, ".")
	cv.fill(sx0 + 4, top_floor, w - 2, top_floor, "#")
	cv.fill(sx0, floor_y - 3, sx1, floor_y - 1, "#")
	cv.spawns["start"] = [3, floor_y - 1]
	cv.spawns["from_prev"] = [3, floor_y - 1]
	var pv: Array = prev_of(ctx["id"])
	_exit(cv, 0, floor_y, pv[0], pv[1])
	_span(cv, 2, 10, floor_y)
	# rest ledges
	var ly := floor_y - 12
	var side := 0
	while ly > top_floor + 6:
		if side == 0:
			cv.fill(sx0, ly, sx0 + 1, ly, "=")
			_span(cv, sx0, sx0 + 1, ly)
		else:
			cv.fill(sx1 - 1, ly, sx1, ly, "=")
			_span(cv, sx1 - 1, sx1, ly)
		side = 1 - side
		ly -= 12
	# wall hazards (thorns / spikes) on the wall faces, spaced so a mistimed jump punishes but a rest ledge is never far
	var hz := "T" if region == "thornwild" else "^"
	var yy := floor_y - 7
	while yy > top_floor + 4:
		cv.set_c(sx0 - 1 if false else sx0, yy, ".")
		if rng.randf() < 0.6:
			cv.set_c(sx1, yy, hz)
		yy -= 7
	var nx2: Array = next_of(ctx["id"])
	_exit(cv, w - 2, top_floor, nx2[0], nx2[1])
	cv.spawns["from_next"] = [w - 6, top_floor - 1]
	_span(cv, sx0 + 4, w - 3, top_floor)
	cv.ent({"t": "i", "kind": "checkpoint", "x": sx0 + 7, "y": top_floor - 1, "id": "top"})
	cv.ent({"t": "i", "kind": "chest", "x": w - 5, "y": top_floor - 1, "id": "cv", "item": {"heart": 1}})
	cv.ent({"t": "i", "kind": "hint", "x": 8, "y": floor_y - 1, "id": "hs", "text": "Leap at the wall, then leap again from the opposite one. Rest on the ledges."})
	# flyers in the shaft
	for i in 2 + idx / 3:
		cv.ent({"t": "enemy", "k": "drone" if region != "thornwild" else "stalker", "x": sx0 + 2, "y": floor_y - 20 - i * 12, "patrol": 40.0})
	_place_enemies(cv, ctx, 3, 2, 10)
	cv.meta["vertical"] = true
	cv.meta["shaft"] = true
	return cv


# =============================================================== puzzle rooms
static func _room_puzzle(ctx: Dictionary) -> Cv:
	var region: String = ctx["region"]
	var rng: RandomNumberGenerator = ctx["rng"]
	var kind: String = ctx["kind"]
	var idx: int = ctx["idx"]
	var w := 68
	var cv := Cv.new(w, 28)
	_walls(cv, _has_ceiling(region), region)
	var fy := 22
	_fill_ground(cv, 0, w - 1, fy, region)
	cv.spawns["start"] = [3, fy - 1]
	cv.spawns["from_prev"] = [3, fy - 1]
	var pv: Array = prev_of(ctx["id"])
	_exit(cv, 0, fy, pv[0], pv[1])
	_span(cv, 2, w - 3, fy)
	var nx: Array = next_of(ctx["id"])
	_exit(cv, w - 1, fy, nx[0], nx[1])
	cv.spawns["from_next"] = [w - 4, fy - 1]
	var gx := w - 8
	# the gate that blocks the exit corridor
	var gates: Array = []
	for yy in range(fy - 8, fy):
		cv.set_c(gx, yy, "G")
		gates.append([gx, yy])
	# the corridor above the gate is sealed so it cannot be jumped
	for yy in range(1, fy - 8):
		cv.set_c(gx, yy, "#")
	cv.ent({"t": "i", "kind": "checkpoint", "x": 7, "y": fy - 1, "id": "p0"})
	var hints: Array = Story.HINTS[region]
	match kind:
		"puzzle_seq", "puzzle_mixed":
			var count := 3 if kind == "puzzle_seq" else 4
			cv.puzzles["seq"] = {"kind": "sequence", "count": count, "gates": gates}
			# switches on a staircase of platforms
			var positions: Array = [[14, fy - 1], [24, fy - 4], [34, fy - 7], [44, fy - 4]]
			var order: Array = range(1, count + 1)
			order.shuffle()
			# platforms under switches
			cv.fill(20, fy - 3, 28, fy - 3, "=")
			cv.fill(30, fy - 6, 38, fy - 6, "=")
			cv.fill(40, fy - 3, 48, fy - 3, "=")
			cv.fill(26, fy - 2, 28, fy - 2, "=") if false else null
			for i in count:
				var p: Array = positions[i]
				cv.ent({"t": "i", "kind": "switch", "x": p[0], "y": p[1], "group": "seq", "order": order[i], "mode": "hit"})
			cv.ent({"t": "i", "kind": "hint", "x": 11, "y": fy - 1, "id": "h3", "text": "Strike the beacons in the order of their numbers, lowest first. A wrong strike resets them all."})
			if kind == "puzzle_mixed":
				cv.ent({"t": "hazard", "k": "saw", "px": 30.0 * 32.0, "py": float(fy) * 32.0 - 15.0, "speed": 80.0, "pts": [[16.0 * 32.0, float(fy) * 32.0 - 15.0], [44.0 * 32.0, float(fy) * 32.0 - 15.0]]})
		"puzzle_beam":
			cv.puzzles["beam"] = {"kind": "all", "count": 1, "gates": gates}
			var top_y := fy - 8
			cv.fill(5, top_y, 21, top_y, "=")
			for yy in range(top_y, fy):
				cv.set_c(5, yy, "H") if yy < fy else null
			cv.set_c(5, top_y, ".")
			cv.ent({"t": "i", "kind": "emitter", "x": 8, "y": top_y - 1, "dir": 0})
			var sol_a := 1
			var sol_b := 0
			var a_dir := (sol_a + rng.randi_range(1, 3)) % 4
			var b_dir := (sol_b + rng.randi_range(1, 3)) % 4
			cv.ent({"t": "i", "kind": "prism", "x": 18, "y": top_y - 1, "dir": a_dir, "group": "beam"})
			cv.ent({"t": "i", "kind": "prism", "x": 18, "y": fy - 1, "dir": b_dir, "group": "beam"})
			cv.ent({"t": "i", "kind": "target", "x": 34, "y": fy - 1, "group": "beam"})
			cv.meta["beam_solution"] = [sol_a, sol_b]
			cv.ent({"t": "i", "kind": "hint", "x": 11, "y": fy - 1, "id": "h3", "text": "Light travels where the prisms point. Turn them (interact) until the beam reaches the sun-seal."})
		"puzzle_block":
			cv.puzzles["plates"] = {"kind": "all", "count": 2, "gates": gates}
			cv.ent({"t": "i", "kind": "plate", "x": 24, "y": fy - 1, "group": "plates"})
			cv.ent({"t": "i", "kind": "plate", "x": 46, "y": fy - 1, "group": "plates"})
			cv.ent({"t": "push", "x": 34, "y": fy - 1})
			cv.ent({"t": "i", "kind": "reset", "x": 12, "y": fy - 1, "id": "rs"})
			cv.ent({"t": "i", "kind": "hint", "x": 10, "y": fy - 1, "id": "h3", "text": "Two plates, one traveller. Push the block onto a plate (walk into it) and stand on the other. If it jams, touch the rewind stone."})
	_place_enemies(cv, ctx, 3, 14, w - 16)
	_place_items(cv, ctx, 1, 1, 0)
	return cv


# =============================================================== sanctuary and boss arena
static func _room_pre(ctx: Dictionary) -> Cv:
	var region: String = ctx["region"]
	var cv := Cv.new(44, 24)
	var fy := 19
	_walls(cv, _has_ceiling(region), region)
	_fill_ground(cv, 0, cv.w - 1, fy, region)
	cv.spawns["start"] = [4, fy - 1]
	cv.spawns["from_prev"] = [4, fy - 1]
	cv.spawns["from_shortcut"] = [8, fy - 1]
	cv.spawns["from_next"] = [cv.w - 5, fy - 1]
	var pv: Array = prev_of(ctx["id"])
	_exit(cv, 0, fy, pv[0], pv[1])
	var nx: Array = next_of(ctx["id"])
	_exit(cv, cv.w - 1, fy, nx[0], nx[1])
	_span(cv, 2, cv.w - 3, fy)
	cv.ent({"t": "i", "kind": "checkpoint", "x": 16, "y": fy - 1, "id": "pre"})
	cv.ent({"t": "i", "kind": "journal", "x": 22, "y": fy - 1, "id": "jp", "entry": JOURNAL_IDS[region][1]})
	var hints: Array = Story.HINTS[region]
	cv.ent({"t": "i", "kind": "hint", "x": 28, "y": fy - 1, "id": "hp", "text": "The guardian beyond is faster than anything you have met. Heal with H, dodge with Shift, and watch for its warning flashes."})
	cv.ent({"t": "i", "kind": "chest", "x": 33, "y": fy - 1, "id": "cp", "item": {"shards": 80 + 20 * Defs.REGION_ORDER.find(region), "dust": 5}})
	cv.ent({"t": "i", "kind": "npc", "x": 11, "y": fy - 1, "npc": HUB_NPCS[region][0]})
	return cv


const BOSS_REWARDS := {"meadows": "dash", "ember": "wall_jump", "observatory": "stasis", "thornwild": "double_jump", "frostfall": "guardian_pendant", "clockwork": "", "eclipse": ""}


static func _room_boss(ctx: Dictionary) -> Cv:
	var region: String = ctx["region"]
	var cv := Cv.new(46, 26)
	var fy := 21
	_walls(cv, true, region)
	_fill_ground(cv, 0, cv.w - 1, fy, region)
	cv.spawns["start"] = [4, fy - 1]
	cv.spawns["from_prev"] = [4, fy - 1]
	cv.spawns["from_next"] = [cv.w - 5, fy - 1]
	var pv: Array = prev_of(ctx["id"])
	_exit(cv, 0, fy, pv[0], pv[1])
	var nx: Array = next_of(ctx["id"])
	var req := "defeated_" + str(Defs.REGIONS[region]["boss"])
	if nx[0] != "":
		_exit(cv, cv.w - 1, fy, nx[0], nx[1], {"requires": req, "locked_msg": "The way onward is sealed until the guardian falls."})
	else:
		_exit(cv, cv.w - 1, fy, "", "", {"requires": req, "ending": true})
	_span(cv, 2, cv.w - 3, fy)
	# side platforms (one-way) used by several bosses
	cv.fill(8, fy - 5, 13, fy - 5, "=")
	cv.fill(32, fy - 5, 37, fy - 5, "=")
	cv.fill(19, fy - 8, 26, fy - 8, "=")
	var gates: Array = []
	for yy in range(fy - 6, fy):
		gates.append([2, yy])
	cv.meta["arena"] = {"gate": gates, "trigger_x": 8, "reward": BOSS_REWARDS[region], "fy": fy}
	cv.ent({"t": "boss", "k": Defs.REGIONS[region]["boss"], "x": 36, "y": fy - 1})
	cv.puzzles = {}
	return cv
