class_name Spawner
extends RefCounted
## Turns a LevelData's `meta.entities` list into live nodes on a Stage. Coordinates in meta are tile cells;
## an entity stands on the bottom-centre of its cell.

static func wp(x: int, y: int) -> Vector2:
	return Vector2((x + 0.5) * Level.T, (y + 1) * Level.T)


static func populate(stage: Stage, d: LevelData) -> void:
	var lvl := stage.level
	stage.pushblocks.clear()
	stage.puzzles = {}
	stage.puzzle_state = {}
	var pz: Dictionary = d.meta.get("puzzles", {})
	for g in pz:
		stage.puzzles[g] = pz[g]
		var key := "puzzle_%s_%s" % [d.id, g]
		stage.puzzle_state[g] = {"done": Game.flag(key), "next": 1, "count": 0, "plates": {}}
	# cracked walls (skip the ones already broken)
	for y in d.h:
		for x in d.w:
			if d.rows[y][x] == "X":
				if Game.flag("broke_%s_%d_%d" % [d.id, x, y]):
					lvl.set_tile(x, y, Tiles.AIR)
					continue
				var b := Breakable.new()
				b.stage = stage
				b.tx = x
				b.ty = y
				stage.entities.add_child(b)
				stage.hittables.append(b)
	# already-solved puzzles open their gates immediately
	for g in stage.puzzle_state:
		if stage.puzzle_state[g]["done"]:
			stage._open_gates(g, true)
	for e in d.meta.get("entities", []):
		spawn_entity(stage, e)
	stage.refresh_lens()


static func spawn_entity(stage: Stage, e: Dictionary) -> Node:
	var t: String = e.get("t", "")
	var pos := wp(int(e.get("x", 0)), int(e.get("y", 0)))
	match t:
		"enemy":
			var en := Enemy.create(str(e["k"]))
			en.position = pos
			en.stage = stage
			en.level = stage.level
			en.patrol = float(e.get("patrol", 120.0))
			stage.entities.add_child(en)
			stage.enemies.append(en)
			stage.hittables.append(en)
			return en
		"platform":
			var pl := MovingPlatform.new()
			var pts: Array = []
			for p in e["pts"]:
				pts.append(Vector2(float(p[0]) * Level.T + Level.T * 0.5, float(p[1]) * Level.T))
			pl.setup(stage.level, pts, float(e.get("speed", 70.0)), float(e.get("w", 96.0)))
			stage.entities.add_child(pl)
			stage.platforms.append(pl)
			return pl
		"push":
			var pb := PushBlock.new()
			pb.stage = stage
			pb.position = pos
			stage.entities.add_child(pb)
			stage.pushblocks.append(pb)
			return pb
		"hazard":
			var hz := Hazard.create(str(e["k"]), e)
			hz.stage = stage
			hz.position = Vector2(float(e["px"]), float(e["py"]))
			stage.entities.add_child(hz)
			stage.hazards_extra.append(hz)
			return hz
		"boss":
			return stage.spawn_boss(str(e["k"]), pos)
		"i":
			var it := Interactable.create(str(e["kind"]), e)
			it.stage = stage
			it.position = pos
			stage.entities.add_child(it)
			stage.interactables.append(it)
			if it.kind == "switch":
				stage.hittables.append(it)
			if it.kind == "prism" or it.kind == "target" or it.kind == "emitter":
				pass
			return it
	return null
