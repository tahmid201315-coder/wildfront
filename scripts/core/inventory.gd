extends Node
## Autoload "Inv": slot-based inventory with stacking, capacity, durability and equipment moves.

signal changed

const MAX_SLOTS := 72      # absolute upper bound; usable capacity depends on the equipped pack
var slots: Array = []      # each element: {} (empty) or {id, n, dur?}


func _ready() -> void:
	clear()


func clear() -> void:
	slots = []
	slots.resize(MAX_SLOTS)
	for i in MAX_SLOTS:
		slots[i] = {}
	changed.emit()


func capacity() -> int:
	return mini(Game.slots_capacity(), MAX_SLOTS)


func _new_entry(id: String, n: int) -> Dictionary:
	var e := {"id": id, "n": n}
	var it: Dictionary = Data.items[id]
	if it.has("dur") and int(it["dur"]) > 0:
		e["dur"] = float(it["dur"])
	return e


func count(id: String) -> int:
	var c := 0
	for s in slots:
		if not s.is_empty() and s["id"] == id:
			c += int(s["n"])
	return c


## How many more of this item would fit right now.
func room_for(id: String) -> int:
	if not Data.items.has(id):
		return 0
	var lim := Data.stack_limit(id)
	var room := 0
	for i in capacity():
		var s: Dictionary = slots[i]
		if s.is_empty():
			room += lim
		elif s["id"] == id:
			room += maxi(lim - int(s["n"]), 0)
	return room


func can_add(id: String, n: int) -> bool:
	return n > 0 and room_for(id) >= n


## Adds items; returns how many did NOT fit (0 on full success). Never duplicates or loses items.
func add(id: String, n: int) -> int:
	if not Data.items.has(id) or n <= 0:
		return maxi(n, 0)
	var lim := Data.stack_limit(id)
	var left := n
	for i in capacity():
		if left <= 0:
			break
		var s: Dictionary = slots[i]
		if not s.is_empty() and s["id"] == id and int(s["n"]) < lim:
			var t := mini(lim - int(s["n"]), left)
			s["n"] = int(s["n"]) + t
			left -= t
	for i in capacity():
		if left <= 0:
			break
		if slots[i].is_empty():
			var t := mini(lim, left)
			slots[i] = _new_entry(id, t)
			left -= t
	changed.emit()
	return left


func add_entry(e: Dictionary) -> bool:
	## Adds a specific entry (keeps durability) into the first free slot.
	for i in capacity():
		if slots[i].is_empty():
			slots[i] = e.duplicate()
			changed.emit()
			return true
	return false


func remove(id: String, n: int) -> bool:
	if n <= 0 or count(id) < n:
		return false
	var left := n
	for i in range(MAX_SLOTS - 1, -1, -1):
		if left <= 0:
			break
		var s: Dictionary = slots[i]
		if not s.is_empty() and s["id"] == id:
			var t := mini(int(s["n"]), left)
			s["n"] = int(s["n"]) - t
			left -= t
			if int(s["n"]) <= 0:
				slots[i] = {}
	changed.emit()
	return true


func remove_slot(i: int) -> Dictionary:
	var e: Dictionary = slots[i]
	slots[i] = {}
	changed.emit()
	return e


func has_all(ing: Dictionary, mult: float = 1.0) -> bool:
	for id in ing:
		if count(id) < int(ceil(float(ing[id]) * mult)):
			return false
	return true


func missing(ing: Dictionary, mult: float = 1.0) -> Dictionary:
	var m := {}
	for id in ing:
		var need := int(ceil(float(ing[id]) * mult))
		var have := count(id)
		if have < need:
			m[id] = need - have
	return m


## Simulated check: would the output fit after consuming the ingredients?
func can_craft(ing: Dictionary, out_id: String, out_n: int, mult: float = 1.0) -> bool:
	if not has_all(ing, mult):
		return false
	var backup := serialize()
	for id in ing:
		remove(id, int(ceil(float(ing[id]) * mult)))
	var ok := can_add(out_id, out_n)
	deserialize(backup)
	return ok


func sort_inventory() -> void:
	var order := {"weapon": 0, "armor": 1, "suit": 1, "pack": 1, "tool": 2, "medicine": 3, "food": 4, "resource": 5, "quest": 6}
	var entries: Array = []
	for s in slots:
		if not s.is_empty():
			entries.append(s)
	var merged := {}
	var singles: Array = []
	for e in entries:
		var lim := Data.stack_limit(e["id"])
		if lim > 1:
			merged[e["id"]] = int(merged.get(e["id"], 0)) + int(e["n"])
		else:
			singles.append(e)
	var out: Array = []
	for id in merged:
		var left: int = merged[id]
		var lim := Data.stack_limit(id)
		while left > 0:
			var t := mini(lim, left)
			out.append({"id": id, "n": t})
			left -= t
	out.append_array(singles)
	out.sort_custom(func(a, b):
		var ca: int = order.get(Data.items[a["id"]]["cat"], 9)
		var cb: int = order.get(Data.items[b["id"]]["cat"], 9)
		if ca != cb:
			return ca < cb
		return String(Data.items[a["id"]]["name"]) < String(Data.items[b["id"]]["name"]))
	slots = []
	slots.resize(MAX_SLOTS)
	for i in MAX_SLOTS:
		slots[i] = out[i] if i < out.size() else {}
	changed.emit()


# ---- tools
## Best tool of a kind that meets min tier. Returns slot index or -1.
func best_tool(kind: String, min_tier: int = 0) -> int:
	var best := -1
	var bp := -1.0
	for i in capacity():
		var s: Dictionary = slots[i]
		if s.is_empty():
			continue
		var it: Dictionary = Data.items[s["id"]]
		if it.get("tool", "") == kind and int(it["tier"]) >= min_tier and float(it["power"]) > bp:
			best = i
			bp = float(it["power"])
	return best


func damage_slot(i: int, amount: float) -> bool:
	## Returns true if the item broke.
	var s: Dictionary = slots[i]
	if s.is_empty() or not s.has("dur"):
		return false
	s["dur"] = float(s["dur"]) - amount
	if float(s["dur"]) <= 0.0:
		slots[i] = {}
		changed.emit()
		return true
	return false


# ---- equipment
func equip_slot_index(i: int) -> String:
	var s: Dictionary = slots[i]
	if s.is_empty():
		return "Nothing there."
	var it: Dictionary = Data.items[s["id"]]
	var slot := ""
	if it["cat"] == "weapon":
		slot = "weapon"
	elif it.has("slot"):
		slot = str(it["slot"])
	else:
		return "That cannot be equipped."
	var entry: Dictionary = {"id": s["id"], "dur": float(s.get("dur", 0.0))}
	var old: Dictionary = Game.equip.get(slot, {})
	slots[i] = {}
	Game.equip[slot] = entry
	if not old.is_empty():
		var back := {"id": old["id"], "n": 1}
		if float(old.get("dur", 0.0)) > 0.0:
			back["dur"] = float(old["dur"])
		slots[i] = back
	# shrinking the pack must not strand items outside capacity
	if slot == "pack":
		var cap := capacity()
		for k in range(cap, MAX_SLOTS):
			if not slots[k].is_empty():
				var moved := false
				for j in cap:
					if slots[j].is_empty():
						slots[j] = slots[k]
						slots[k] = {}
						moved = true
						break
				if not moved:
					# undo
					slots[k] = slots[k]
					Game.equip[slot] = old
					slots[i] = {"id": entry["id"], "n": 1}
					return "Make room in your pack first."
	Game.equipment_changed.emit()
	changed.emit()
	return ""


func unequip(slot: String) -> String:
	if not Game.equip.has(slot):
		return ""
	var e: Dictionary = Game.equip[slot]
	var back := {"id": e["id"], "n": 1}
	if float(e.get("dur", 0.0)) > 0.0:
		back["dur"] = float(e["dur"])
	if slot == "pack":
		var used := 0
		for k in range(BASE_CAP(), MAX_SLOTS):
			if not slots[k].is_empty():
				used += 1
		if used > 0:
			return "Empty the extra pack slots first."
	if not add_entry(back):
		return "Inventory is full."
	Game.equip.erase(slot)
	Game.equipment_changed.emit()
	changed.emit()
	return ""


func BASE_CAP() -> int:
	return Game.BASE_SLOTS


# ---- persistence
func serialize() -> Array:
	var out: Array = []
	for s in slots:
		out.append(s.duplicate())
	return out


func deserialize(arr: Variant) -> void:
	clear()
	if typeof(arr) != TYPE_ARRAY:
		return
	var i := 0
	for e in arr:
		if i >= MAX_SLOTS:
			break
		if typeof(e) == TYPE_DICTIONARY and not (e as Dictionary).is_empty():
			var id := str(e.get("id", ""))
			if Data.items.has(id):
				var n := clampi(int(e.get("n", 1)), 1, Data.stack_limit(id))
				var entry := {"id": id, "n": n}
				if e.has("dur"):
					entry["dur"] = float(e["dur"])
				slots[i] = entry
		i += 1
	changed.emit()
