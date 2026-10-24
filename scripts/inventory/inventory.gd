extends Node
## Shared inventory service (autoload "Inv"). Every mutation is validated first.

signal changed

var slots: Array = []   # each entry: {"id": String, "n": int} or null


func _ready() -> void:
	clear()


func clear() -> void:
	slots = []
	slots.resize(Data.PACK_SLOTS)
	for i in slots.size():
		slots[i] = null
	changed.emit()


func stack_limit(id: String) -> int:
	return int(Data.get_item(id).get("stack", 1))


func count(id: String) -> int:
	var total := 0
	for s in slots:
		if s != null and s["id"] == id:
			total += int(s["n"])
	return total


## How many more of `id` fit given the current slots (optionally a simulated slot list).
func free_space_for(id: String, sim: Array = []) -> int:
	var arr: Array = slots if sim.is_empty() else sim
	var lim := stack_limit(id)
	if lim <= 0:
		return 0
	var space := 0
	for s in arr:
		if s == null:
			space += lim
		elif s["id"] == id:
			space += lim - int(s["n"])
	return space


func can_add(id: String, n: int) -> bool:
	return Data.items.has(id) and n > 0 and free_space_for(id) >= n


## Adds as many as fit; returns how many did NOT fit (0 = all added).
func add(id: String, n: int) -> int:
	if not Data.items.has(id) or n <= 0:
		return maxi(n, 0)
	var remaining := n
	var lim := stack_limit(id)
	for s in slots:
		if remaining <= 0:
			break
		if s != null and s["id"] == id and int(s["n"]) < lim:
			var put := mini(lim - int(s["n"]), remaining)
			s["n"] += put
			remaining -= put
	for i in slots.size():
		if remaining <= 0:
			break
		if slots[i] == null:
			var put2 := mini(lim, remaining)
			slots[i] = {"id": id, "n": put2}
			remaining -= put2
	if remaining < n:
		changed.emit()
	return remaining


func has_all(req: Dictionary) -> bool:
	for id in req:
		if count(id) < int(req[id]):
			return false
	return true


func missing(req: Dictionary) -> Dictionary:
	var out := {}
	for id in req:
		var need := int(req[id]) - count(id)
		if need > 0:
			out[id] = need
	return out


func remove(id: String, n: int) -> bool:
	if n <= 0 or count(id) < n:
		return false
	var remaining := n
	for i in range(slots.size() - 1, -1, -1):
		var s = slots[i]
		if s != null and s["id"] == id:
			var take := mini(int(s["n"]), remaining)
			s["n"] -= take
			remaining -= take
			if int(s["n"]) <= 0:
				slots[i] = null
			if remaining <= 0:
				break
	changed.emit()
	return true


func _simulate_after(remove_req: Dictionary) -> Array:
	var sim: Array = []
	for s in slots:
		sim.append(null if s == null else {"id": s["id"], "n": s["n"]})
	for id in remove_req:
		var remaining := int(remove_req[id])
		for i in range(sim.size() - 1, -1, -1):
			if remaining <= 0:
				break
			if sim[i] != null and sim[i]["id"] == id:
				var take := mini(int(sim[i]["n"]), remaining)
				sim[i]["n"] -= take
				remaining -= take
				if int(sim[i]["n"]) <= 0:
					sim[i] = null
	return sim


## True if the recipe could be crafted from the current inventory (ingredients + room for output).
func can_craft(recipe: Dictionary) -> bool:
	if not has_all(recipe["ingredients"]):
		return false
	var sim := _simulate_after(recipe["ingredients"])
	return free_space_for(recipe["result"], sim) >= int(recipe["qty"])


func sort_items() -> void:
	var entries: Array = []
	for s in slots:
		if s != null:
			entries.append(s)
	entries.sort_custom(func(a, b):
		var ka: String = str(Data.get_item(a["id"]).get("kind", "")) + a["id"]
		var kb: String = str(Data.get_item(b["id"]).get("kind", "")) + b["id"]
		return ka < kb)
	for i in slots.size():
		slots[i] = entries[i] if i < entries.size() else null
	changed.emit()


func serialize() -> Array:
	var out: Array = []
	for s in slots:
		out.append(null if s == null else [s["id"], int(s["n"])])
	return out


func deserialize(arr: Array) -> void:
	clear()
	for i in mini(arr.size(), slots.size()):
		var e = arr[i]
		if e is Array and e.size() == 2 and Data.items.has(str(e[0])) and int(e[1]) > 0:
			slots[i] = {"id": str(e[0]), "n": mini(int(e[1]), stack_limit(str(e[0])))}
	changed.emit()
