class_name Verifier
extends RefCounted
## Conservative reachability model for generated rooms. It does not prove a room is fun; it proves that Kael, using only
## the abilities he is guaranteed to own in that region, can reach every interactive object that matters and can always
## reach the way onward. The movement model is deliberately tighter than the real physics (tests check that too).

var d: LevelData
var w: int = 0
var h: int = 0
var abil: Dictionary = {}
var gates_closed: bool = true
var x_closed: bool = true
var nodes: Dictionary = {}          # idx -> kind ("stand","swim","ladder","cling")
var adj: Dictionary = {}            # idx -> Array of idx
var radj: Dictionary = {}
const JV := 650.0
const JV_DOUBLE := 815.0
const G := 1900.0
const VX := 262.0 * 0.82
const DASH_PX := 78.0


func _init(data: LevelData, abilities: Array) -> void:
	d = data
	w = d.w
	h = d.h
	for a in abilities:
		abil[a] = true


func ch(x: int, y: int) -> String:
	if x < 0 or x >= w:
		return "#"
	if y < 0:
		return "."
	if y >= h:
		return "."
	return d.rows[y][x]


func solid(x: int, y: int) -> bool:
	var c := ch(x, y)
	if c == "#" or c == "B" or c == "I":
		return true
	if c == "G":
		return gates_closed
	if c == "X":
		return x_closed
	return false


func hazard(x: int, y: int) -> bool:
	var c := ch(x, y)
	return c == "^" or c == "L" or c == "T"


func clear_at(x: int, y: int) -> bool:
	return not solid(x, y) and not hazard(x, y)


func key(x: int, y: int) -> int:
	return y * w + x


func _is_stand(x: int, y: int) -> bool:
	if not clear_at(x, y) or not clear_at(x, y - 1):
		return false
	var c := ch(x, y)
	if c == "H" or c == "~":
		return true
	var below := ch(x, y + 1)
	if solid(x, y + 1) or below == "=":
		return true
	return false


func build(extra_nodes: Array = []) -> void:
	nodes.clear()
	adj.clear()
	radj.clear()
	for y in range(1, h):
		for x in range(1, w - 1):
			if _is_stand(x, y):
				var c := ch(x, y)
				nodes[key(x, y)] = "ladder" if c == "H" else ("swim" if c == "~" else "stand")
	for e in extra_nodes:
		var ex: int = e[0]
		var ey: int = e[1]
		if clear_at(ex, ey) and clear_at(ex, ey - 1):
			nodes[key(ex, ey)] = "stand"
	if abil.has("wall_jump"):
		for y in range(1, h):
			for x in range(1, w - 1):
				var k := key(x, y)
				if nodes.has(k) or not clear_at(x, y) or not clear_at(x, y - 1):
					continue
				if solid(x - 1, y) or solid(x + 1, y):
					nodes[k] = "cling"
	var keys := nodes.keys()
	for k in keys:
		adj[k] = []
		radj[k] = []
	for k in keys:
		_edges_from(k)


func _link(a: int, b: int) -> void:
	if a == b:
		return
	if not (adj[a] as Array).has(b):
		(adj[a] as Array).append(b)
		(radj[b] as Array).append(a)


func _edges_from(k: int) -> void:
	var x := k % w
	var y := k / w
	var kind: String = nodes[k]
	# walking / swimming / ladder neighbours
	for dx in [-1, 1]:
		var nk := key(x + dx, y)
		if nodes.has(nk) and kind != "cling" and nodes[nk] != "cling":
			_link(k, nk)
	if kind in ["ladder", "swim"]:
		for dy in [-1, 1]:
			var nk2 := key(x, y + dy)
			if nodes.has(nk2) and nodes[nk2] == kind:
				_link(k, nk2)
	# drops off ledges: walk out then fall straight down in columns up to 3 away
	if kind != "cling":
		for dir in [-1, 1]:
			for drift in range(1, 4):
				var cx: int = x + dir * drift
				var ok := true
				for j in range(1, drift + 1):
					if not (clear_at(x + dir * j, y) and clear_at(x + dir * j, y - 1)):
						ok = false
				if not ok:
					break
				var y2 := y
				while y2 < h and clear_at(cx, y2):
					if nodes.has(key(cx, y2)) and y2 > y:
						_link(k, key(cx, y2))
						break
					y2 += 1
	# jumps (with arc clearance)
	var jv := JV_DOUBLE if abil.has("double_jump") else JV
	var max_up := 5 if abil.has("double_jump") else 3
	if kind != "cling":
		for ty in range(y - max_up, y + 15):
			for tx in range(x - 11, x + 12):
				if tx == x and ty == y:
					continue
				var tk := key(tx, ty)
				if not nodes.has(tk):
					continue
				if _can_jump(x, y, tx, ty, jv):
					_link(k, tk)
	# wall-jump hops between walls
	if abil.has("wall_jump") and (kind == "cling" or _touches_wall(x, y)):
		for ty in range(y - 3, y + 8):
			for tx in range(x - 4, x + 5):
				var tk2 := key(tx, ty)
				if tk2 == k or not nodes.has(tk2):
					continue
				if nodes[tk2] == "cling" or _touches_wall(tx, ty) or kind == "cling":
					if _line_free(x, y, tx, ty):
						_link(k, tk2)


func _touches_wall(x: int, y: int) -> bool:
	return solid(x - 1, y) or solid(x + 1, y) or solid(x - 1, y - 1) or solid(x + 1, y - 1)


func _line_free(x0: int, y0: int, x1: int, y1: int) -> bool:
	var n := maxi(absi(x1 - x0), absi(y1 - y0))
	for i in range(1, n):
		var cx := x0 + int(round(float(x1 - x0) * i / n))
		var cy := y0 + int(round(float(y1 - y0) * i / n))
		if not clear_at(cx, cy) or not clear_at(cx, cy - 1):
			return false
	return true


func _can_jump(sx: int, sy: int, tx: int, ty: int, jv: float) -> bool:
	var hpx := float((sy - ty) * 32)
	var disc := jv * jv - 2.0 * G * hpx
	if hpx > 0.0 and jv * jv / (2.0 * G) < hpx + 10.0:
		return false
	if disc < 0.0:
		return false
	var t_land := (jv + sqrt(disc)) / G
	var dxp := absf(float(tx - sx)) * 32.0
	var dxe := maxf(dxp - 28.0, 0.0)   # take off from the ledge edge and land on the far edge
	var reach := VX * t_land + (DASH_PX if abil.has("dash") else 0.0)
	if abil.has("double_jump"):
		reach *= 0.9
	if dxe > reach:
		return false
	var dir := 1.0 if tx >= sx else -1.0
	var x0 := sx * 32.0 + 16.0
	var y0 := float(sy + 1) * 32.0
	var samples := 16
	# horizontal travel may be spread evenly, held back until late in the jump, or done early; any clear schedule counts
	for mode in 3:
		if mode == 1 and dxe > VX * t_land * 0.55:
			continue
		if mode == 2 and dxe > VX * t_land * 0.55:
			continue
		var clear := true
		for i in range(2, samples - 1):
			var u := float(i) / float(samples)
			var prog := u
			if mode == 1:
				prog = clampf((u - 0.4) / 0.6, 0.0, 1.0)
			elif mode == 2:
				prog = clampf(u / 0.6, 0.0, 1.0)
			var t := t_land * u
			var px := x0 + dir * dxp * prog
			var py := y0 - (jv * t - G * t * t * 0.5)
			if _body_hits(px, py):
				clear = false
				break
		if clear:
			return true
	return false


func _body_hits(px: float, py: float) -> bool:
	var x0 := int(floor((px - 9.0) / 32.0))
	var x1 := int(floor((px + 9.0) / 32.0))
	var y0 := int(floor((py - 40.0) / 32.0))
	var y1 := int(floor((py - 2.0) / 32.0))
	for yy in range(y0, y1 + 1):
		for xx in range(x0, x1 + 1):
			if solid(xx, yy):
				return true
	return false


func reachable_from(start: int) -> Dictionary:
	var seen := {start: true}
	var q: Array = [start]
	var i := 0
	while i < q.size():
		var k: int = q[i]
		i += 1
		for n in adj.get(k, []):
			if not seen.has(n):
				seen[n] = true
				q.append(n)
	return seen


func can_reach_set(targets: Array) -> Dictionary:
	var seen := {}
	var q: Array = []
	for t in targets:
		if nodes.has(t):
			seen[t] = true
			q.append(t)
	var i := 0
	while i < q.size():
		var k: int = q[i]
		i += 1
		for n in radj.get(k, []):
			if not seen.has(n):
				seen[n] = true
				q.append(n)
	return seen


func node_near(x: int, y: int) -> int:
	# a node Kael can stand on while touching an object occupying cell (x, y)
	for dx in [0, -1, 1, -2, 2]:
		for dy in [0, -1]:
			var k := key(x + dx, y + dy)
			if nodes.has(k):
				return k
	return -1


static func check_room(data: LevelData) -> Dictionary:
	var problems: Array = []
	var abilities: Array = data.meta.get("abilities", [])
	var extra: Array = data.meta.get("platform_nodes", [])
	var spawns: Dictionary = data.meta.get("spawns", {})
	var ents: Array = data.meta.get("entities", [])
	var sp: Array = spawns.get("start", [3, 3])

	# ---- phase A: gates and cracked walls closed. Puzzle triggers and everything outside the gate must be reachable.
	var va := Verifier.new(data, abilities)
	va.gates_closed = true
	va.x_closed = true
	va.build(extra)
	var s0 := va.key(int(sp[0]), int(sp[1]))
	if not va.nodes.has(s0):
		problems.append("spawn is not on standable ground: %s" % [sp])
		return {"ok": false, "problems": problems, "nodes": va.nodes.size()}
	var ra := va.reachable_from(s0)
	var gated: bool = not data.meta.get("puzzles", {}).is_empty() and data.meta.get("kind", "") in ["puzzle_seq", "puzzle_beam", "puzzle_block", "puzzle_mixed"]
	for e in ents:
		if e.get("t", "") != "i":
			continue
		var kd: String = e["kind"]
		if kd in ["exit"]:
			continue
		if kd in ["target", "emitter"]:
			continue
		var nk := va.node_near(int(e["x"]), int(e["y"]))
		if nk < 0 or not ra.has(nk):
			if e["kind"] == "chest" and str(e.get("id", "")).begins_with("secret"):
				continue
			problems.append("%s at (%d,%d) unreachable before puzzle" % [kd, int(e["x"]), int(e["y"])])
	# left exit reachable (can always go back)
	for e in ents:
		if e.get("t", "") == "i" and e["kind"] == "exit" and int(e["x"]) == 0:
			var nk2 := va.node_near(int(e["x"]), int(e["y"]))
			if nk2 < 0 or not ra.has(nk2):
				problems.append("left exit unreachable")

	# ---- phase B: gates open
	var vb := Verifier.new(data, abilities)
	vb.gates_closed = false
	vb.x_closed = true
	vb.build(extra)
	var rb := vb.reachable_from(s0)
	var exit_keys: Array = []
	for e in ents:
		if e.get("t", "") == "i" and e["kind"] == "exit":
			var nk3 := vb.node_near(int(e["x"]), int(e["y"]))
			if nk3 >= 0:
				exit_keys.append(nk3)
			if int(e["x"]) > 1 and (nk3 < 0 or not rb.has(nk3)):
				problems.append("exit at x=%d unreachable" % int(e["x"]))
	# from the right entrance the player must be able to get back to the left exit
	var sn: Array = spawns.get("from_next", [])
	if not sn.is_empty():
		var kn := vb.key(int(sn[0]), int(sn[1]))
		if not vb.nodes.has(kn):
			problems.append("from_next spawn not standable")
		else:
			var rn := vb.reachable_from(kn)
			for e in ents:
				if e.get("t", "") == "i" and e["kind"] == "exit" and int(e["x"]) == 0:
					var nk4 := vb.node_near(0, int(e["y"]))
					if nk4 >= 0 and not rn.has(nk4):
						problems.append("cannot go back from the right entrance to the left exit")

	# ---- phase C: secrets open; every reachable node must still be able to get out (no soft locks)
	var vc := Verifier.new(data, abilities)
	vc.gates_closed = false
	vc.x_closed = false
	vc.build(extra)
	var rc := vc.reachable_from(s0)
	var out_keys: Array = []
	for e in ents:
		if e.get("t", "") == "i" and e["kind"] == "exit":
			var nk5 := vc.node_near(int(e["x"]), int(e["y"]))
			if nk5 >= 0:
				out_keys.append(nk5)
	var back := vc.can_reach_set(out_keys)
	var stuck := 0
	for k in rc:
		if not back.has(k) and vc.nodes[k] != "cling":
			stuck += 1
	if stuck > 0:
		problems.append("%d reachable cells cannot reach an exit (possible soft lock)" % stuck)
	for c in data.meta.get("secret_cells", []):
		var kk := vc.node_near(int(c[0]), int(c[1]))
		if kk < 0 or not rc.has(kk):
			problems.append("secret cell %s unreachable" % [c])
	return {"ok": problems.is_empty(), "problems": problems, "nodes": va.nodes.size()}
