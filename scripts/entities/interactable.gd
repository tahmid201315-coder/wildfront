class_name Interactable
extends Node2D
## Everything Kael can touch or use: shrines (checkpoints), chests, doors, switches, plates, journals, NPCs, altars, hint stones,
## beam emitters/prisms/targets. One class dispatching on `kind` keeps the stage's bookkeeping simple.

var stage: Stage
var kind: String = "checkpoint"
var props: Dictionary = {}
var size: Vector2 = Vector2(40, 52)
var used: bool = false
var active: bool = false
var t: float = 0.0
var alive: bool = true
var cooldown: float = 0.0
var group: String = ""
var order: int = 0
var frozen_t: float = 0.0
var _pressed: bool = false
var _prism_dir: int = 0
var _beam_pts: PackedVector2Array = PackedVector2Array()
var _solved_fx: float = 0.0
var uid: int = 0
static var _c: int = 50000


static func create(k: String, p: Dictionary) -> Interactable:
	var i := Interactable.new()
	i.kind = k
	i.props = p
	_c += 1
	i.uid = _c
	i.group = str(p.get("group", ""))
	i.order = int(p.get("order", 0))
	return i


func _ready() -> void:
	z_index = 2
	match kind:
		"checkpoint": size = Vector2(40, 64)
		"chest": size = Vector2(38, 28)
		"exit": size = Vector2(int(props.get("w", 1)) * 32, int(props.get("h", 3)) * 32)
		"switch": size = Vector2(30, 34)
		"plate": size = Vector2(46, 8)
		"npc": size = Vector2(30, 52)
		"journal": size = Vector2(30, 40)
		"altar": size = Vector2(56, 60)
		"hint": size = Vector2(34, 40)
		"reset": size = Vector2(34, 44)
		"emitter": size = Vector2(30, 30)
		"prism": size = Vector2(30, 30); _prism_dir = int(props.get("dir", 0))
		"target": size = Vector2(32, 32)
		"boss_gate": size = Vector2(int(props.get("w", 1)) * 32, int(props.get("h", 3)) * 32)
	if kind in ["chest", "altar", "journal"] and Game.flag(flag_key()):
		used = true
	if kind == "switch" and group != "" and stage.puzzle_done(group):
		active = true


func flag_key() -> String:
	return "%s_%s_%s" % [kind, stage.room_id, str(props.get("id", "0"))]


func rect_world() -> Rect2:
	return Rect2(position.x - size.x * 0.5, position.y - size.y, size.x, size.y)


func use_rect() -> Rect2:
	return rect_world().grow(6.0)


func can_use() -> bool:
	match kind:
		"checkpoint", "npc", "hint", "reset": return true
		"chest", "journal", "altar": return not used
		"exit": return props.get("mode", "touch") == "interact"
		"switch": return not active and props.get("mode", "hit") != "hit"
		"prism": return true
		"boss_gate": return false
	return false


func prompt() -> String:
	match kind:
		"checkpoint": return "Rest at the Starshrine"
		"chest": return "Open"
		"exit": return "Enter"
		"switch": return "Activate"
		"npc": return "Talk"
		"journal": return "Read"
		"altar": return "Touch the altar"
		"hint": return "Read inscription"
		"prism": return "Turn prism"
		"reset": return "Touch the rewind stone"
	return "Use"


func tick(dt: float) -> void:
	t += dt
	cooldown = maxf(cooldown - dt, 0.0)
	var p: Player = stage.player
	match kind:
		"exit":
			if props.get("mode", "touch") == "touch" and cooldown <= 0.0 and p.alive and rect_world().intersects(p.rect()):
				if props.get("requires", "") != "" and not Game.flag(props["requires"]):
					if cooldown <= 0.0:
						Game.toast.emit(str(props.get("locked_msg", "It will not open yet.")), "info")
						cooldown = 2.0
					return
				_go()
		"plate":
			var was := _pressed
			_pressed = false
			var r := rect_world().grow_individual(0, 6, 0, 0)
			if p.alive and p.rect().intersects(r) and p.on_floor:
				_pressed = true
			for b in stage.pushblocks:
				if is_instance_valid(b) and b.rect().intersects(r):
					_pressed = true
			if _pressed != was:
				Sfx.play("switch")
				stage.plate_changed(group, self, _pressed)
		"switch":
			pass
		"emitter", "prism", "target":
			if kind == "target" and stage.puzzle_done(group):
				_solved_fx += dt
		"checkpoint":
			if active and Engine.get_physics_frames() % 6 == 0:
				stage.fx.sparkle(position + Vector2(randf_range(-10, 10), -randf_range(10, 56)), Color(0.6, 0.95, 1.0))
	if kind == "emitter":
		_cast_beam()
	queue_redraw()


func _go() -> void:
	cooldown = 1.0
	Sfx.play("door")
	stage.request_room_change(str(props["to"]), str(props.get("entry", "start")))


# --------------------------------------------------------------- use
func use(p: Player) -> void:
	match kind:
		"checkpoint":
			active = true
			Game.full_restore()
			stage.set_checkpoint(str(props.get("id", "start")), position)
			stage.fx.ring(position + Vector2(0, -30), Color(0.6, 0.95, 1.0))
			stage.fx.burst(position + Vector2(0, -30), Color(0.6, 0.95, 1.0), 14, 200.0)
			Game.toast.emit("Starshrine attuned. Health and heals restored.", "good")
			Sfx.play("checkpoint")
			Game.set_flag("shrine_" + stage.room_id + "_" + str(props.get("id", "start")))
			Game.event.emit("checkpoint")
			stage.autosave()
		"chest":
			_open_chest()
		"exit":
			_go()
		"switch":
			_flip()
		"npc":
			stage.talk_to(str(props.get("npc", "")), self)
		"journal":
			used = true
			Game.set_flag(flag_key())
			Game.set_flag("journal_" + str(props.get("entry", "")))
			Sfx.play("pickup")
			Game.toast.emit("Journal page found: " + str(Story.JOURNALS.get(props.get("entry", ""), {}).get("title", "Page")), "good")
			Game.progress_changed.emit()
			Game.event.emit("journal")
			stage.show_text(Story.JOURNALS.get(props.get("entry", ""), {}).get("title", "Journal"), str(Story.JOURNALS.get(props.get("entry", ""), {}).get("text", "")))
		"hint":
			stage.show_text("Inscription", str(props.get("text", "...")) if Game.settings.get("hints", true) else "The stone is worn smooth. (Hints are switched off in Settings.)")
		"altar":
			_use_altar()
		"reset":
			for b in stage.pushblocks:
				if is_instance_valid(b):
					b.position = b.home
					b.vel = Vector2.ZERO
			Sfx.play("switch")
			stage.fx.ring(position + Vector2(0, -20), Color(0.8, 0.9, 1.0))
		"prism":
			_prism_dir = (_prism_dir + 1) % 4
			Sfx.play("switch")
			stage.fx.ring(position + Vector2(0, -15), Color(1.0, 0.9, 0.5))


func _open_chest() -> void:
	used = true
	Game.set_flag(flag_key())
	Sfx.play("chest")
	var c := position + Vector2(0, -20)
	stage.fx.burst(c, Color(1.0, 0.9, 0.5), 18, 240.0)
	stage.fx.ring(c, Color(1.0, 0.9, 0.5))
	var item: Dictionary = props.get("item", {"shards": 20})
	var msg := ""
	if item.has("shards"):
		Game.add_shards(int(item["shards"]))
		msg += "%d Star Shards  " % int(item["shards"])
	if item.has("dust"):
		Game.dust += int(item["dust"])
		msg += "%d Aether Dust  " % int(item["dust"])
	if item.has("equip"):
		Game.give_equipment(str(item["equip"]))
		msg += Defs.EQUIPMENT[item["equip"]]["name"] + "  "
	if item.has("skill_point"):
		Game.skill_points += int(item["skill_point"])
		msg += "+%d Skill Point  " % int(item["skill_point"])
	if item.has("heart"):
		Game.heart_pieces += 1
		if Game.heart_pieces % 3 == 0:
			Game.bonus_hp += 10
			msg += "Star Heart complete: +10 max health  "
		else:
			msg += "Star Heart piece (%d/3)  " % (Game.heart_pieces % 3)
	Game.stats_changed.emit()
	Game.progress_changed.emit()
	Game.toast.emit("Found: " + msg.strip_edges(), "good")
	Game.event.emit("chest")


func _use_altar() -> void:
	used = true
	Game.set_flag(flag_key())
	var what := str(props.get("grant", ""))
	stage.fx.burst(position + Vector2(0, -40), Color(0.7, 1.0, 1.0), 30, 300.0)
	stage.fx.ring(position + Vector2(0, -40), Color(0.7, 1.0, 1.0))
	stage.shake(4.0)
	Sfx.play("ability")
	if what in Game.ABILITY_NAMES:
		Game.unlock_ability(what)
	elif what != "":
		Game.give_equipment(what)
	Game.event.emit("altar")
	stage.autosave()


func on_stasis(time_s: float) -> void:
	frozen_t = time_s


# --------------------------------------------------------------- switches & puzzles
func hit_rect() -> Rect2:
	return rect_world()


func take_hit(_info: Dictionary) -> bool:
	if kind == "switch" and props.get("mode", "hit") == "hit" and not active:
		_flip()
		return true
	return false


func _flip() -> void:
	if active:
		return
	Sfx.play("switch")
	stage.fx.ring(position + Vector2(0, -17), Color(1.0, 0.9, 0.4))
	stage.switch_pressed(group, self)


func set_active(v: bool) -> void:
	active = v


# beam: emitter shoots along dir; prisms redirect; target solves group when lit
func _cast_beam() -> void:
	var dirs := [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
	var pos := position + Vector2(0, -size.y * 0.5)
	var d: Vector2 = dirs[int(props.get("dir", 0))]
	var pts := PackedVector2Array([pos - position])
	var used_prisms := {}
	for hop in 6:
		var steps := 0
		var hit: Node = null
		while steps < 160:
			pos += d * 8.0
			steps += 1
			if Tiles.is_solid(stage.level.tile_at_px(pos)):
				break
			for o in stage.interactables:
				if o == self or not is_instance_valid(o):
					continue
				if (o.kind == "prism" or o.kind == "target") and o.rect_world().has_point(pos) and not used_prisms.has(o):
					hit = o
					break
			if hit != null:
				break
		pts.append(pos - position)
		if hit == null:
			break
		if hit.kind == "target":
			if not stage.puzzle_done(hit.group):
				stage.beam_hit_target(hit.group, hit)
			break
		used_prisms[hit] = true
		pos = hit.position + Vector2(0, -hit.size.y * 0.5)
		d = dirs[hit._prism_dir]
		pts.append(pos - position)
	_beam_pts = pts


func _draw() -> void:
	var glow := Color(0.6, 0.95, 1.0)
	match kind:
		"checkpoint": _art_shrine()
		"chest": _art_chest()
		"exit": _art_exit()
		"switch": _art_switch()
		"plate":
			var down := _pressed
			draw_rect(Rect2(-size.x * 0.5, -(3.0 if down else 7.0), size.x, 3.0 if down else 7.0), Color(0.55, 0.5, 0.4))
			draw_rect(Rect2(-size.x * 0.5 + 4, -(3.0 if down else 7.0), size.x - 8, 2.0), glow if down else Color(0.4, 0.35, 0.3))
		"npc": _art_npc()
		"journal":
			var b := sin(t * 3.0) * 2.0
			draw_rect(Rect2(-11, -30 + b, 22, 28), Color(0.5, 0.3, 0.2) if not used else Color(0.35, 0.28, 0.25))
			draw_rect(Rect2(-9, -28 + b, 18, 24), Color(0.95, 0.9, 0.75) if not used else Color(0.7, 0.68, 0.6))
			for i in 4:
				draw_line(Vector2(-6, -24 + b + i * 5), Vector2(6, -24 + b + i * 5), Color(0.4, 0.3, 0.2), 1.0)
			if not used:
				draw_circle(Vector2(0, -16 + b), 20.0, Color(1.0, 0.95, 0.6, 0.15))
		"altar": _art_altar()
		"reset":
			draw_rect(Rect2(-12, -40, 24, 40), Color(0.4, 0.42, 0.5))
			draw_arc(Vector2(0, -22), 8.0, 0.5, TAU - 0.5, 14, glow, 2.5, true)
			draw_colored_polygon(PackedVector2Array([Vector2(5, -33), Vector2(11, -26), Vector2(3, -25)]), glow)
		"hint":
			draw_rect(Rect2(-14, -38, 28, 38), Color(0.45, 0.47, 0.5))
			draw_rect(Rect2(-14, -38, 28, 38), Color(0.1, 0.1, 0.15), false, 2.0)
			var gl := 0.5 + 0.5 * sin(t * 2.0)
			draw_circle(Vector2(0, -22), 5.0, Color(glow.r, glow.g, glow.b, 0.3 + 0.4 * gl))
			draw_line(Vector2(-6, -22), Vector2(6, -22), Color(glow.r, glow.g, glow.b, 0.9), 1.5)
			draw_line(Vector2(0, -28), Vector2(0, -16), Color(glow.r, glow.g, glow.b, 0.9), 1.5)
		"emitter":
			draw_circle(Vector2(0, -15), 14.0, Color(0.2, 0.2, 0.3))
			draw_circle(Vector2(0, -15), 9.0, Color(1.0, 0.9, 0.4))
			if _beam_pts.size() > 1:
				var pts := PackedVector2Array()
				for p in _beam_pts:
					pts.append(p)
				draw_polyline(pts, Color(1.0, 0.9, 0.4, 0.3), 9.0)
				draw_polyline(pts, Color(1.0, 0.95, 0.7, 0.95), 3.0)
		"prism":
			var dirs := [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
			var dd: Vector2 = dirs[_prism_dir]
			draw_colored_polygon(PackedVector2Array([Vector2(0, -28), Vector2(13, -15), Vector2(0, -2), Vector2(-13, -15)]), Color(0.7, 0.9, 1.0, 0.85))
			draw_polyline(PackedVector2Array([Vector2(0, -28), Vector2(13, -15), Vector2(0, -2), Vector2(-13, -15), Vector2(0, -28)]), Color(0.1, 0.2, 0.3), 2.0)
			draw_line(Vector2(0, -15), Vector2(0, -15) + dd * 14.0, Color(1.0, 0.8, 0.3), 3.0)
		"target":
			var solved: bool = stage.puzzle_done(group)
			draw_circle(Vector2(0, -16), 15.0, Color(0.15, 0.15, 0.2))
			draw_circle(Vector2(0, -16), 10.0, Color(1.0, 0.9, 0.4) if solved else Color(0.35, 0.3, 0.2))
			if solved:
				draw_arc(Vector2(0, -16), 18.0 + sin(t * 4.0) * 2.0, 0, TAU, 20, Color(1.0, 0.9, 0.4, 0.5), 2.0)


func _art_shrine() -> void:
	var on := active
	var gl := Color(0.55, 0.95, 1.0)
	draw_rect(Rect2(-16, -10, 32, 10), Color(0.4, 0.42, 0.48))
	draw_rect(Rect2(-9, -40, 18, 32), Color(0.5, 0.52, 0.58))
	draw_rect(Rect2(-9, -40, 18, 32), Color(0.1, 0.1, 0.15), false, 2.0)
	var c := Vector2(0, -52 + sin(t * 2.5) * 3.0)
	var pts := PackedVector2Array([c + Vector2(0, -11), c + Vector2(8, 0), c + Vector2(0, 11), c + Vector2(-8, 0)])
	draw_colored_polygon(pts, gl if on else Color(0.4, 0.5, 0.55))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.1, 0.2, 0.3), 1.5)
	if on:
		draw_circle(c, 20.0 + sin(t * 3.0) * 2.0, Color(gl.r, gl.g, gl.b, 0.2))


func _art_chest() -> void:
	var open := used
	draw_rect(Rect2(-19, -20, 38, 20), Color(0.55, 0.33, 0.15))
	draw_rect(Rect2(-19, -20, 38, 20), Color(0.15, 0.08, 0.04), false, 2.0)
	draw_line(Vector2(-19, -12), Vector2(19, -12), Color(0.95, 0.8, 0.3), 2.0)
	if open:
		draw_colored_polygon(PackedVector2Array([Vector2(-19, -20), Vector2(19, -20), Vector2(17, -34), Vector2(-17, -34)]), Color(0.45, 0.27, 0.12))
	else:
		draw_rect(Rect2(-19, -30, 38, 11), Color(0.62, 0.38, 0.17))
		draw_rect(Rect2(-19, -30, 38, 11), Color(0.15, 0.08, 0.04), false, 2.0)
		draw_rect(Rect2(-3, -23, 6, 7), Color(0.95, 0.8, 0.3))
		draw_circle(Vector2(0, -20), 24.0, Color(1.0, 0.9, 0.5, 0.08 + 0.06 * sin(t * 3.0)))


func _art_exit() -> void:
	var r := Rect2(-size.x * 0.5, -size.y, size.x, size.y)
	var mode: String = props.get("mode", "touch")
	if props.get("visible", mode == "interact"):
		draw_rect(r, Color(0.05, 0.05, 0.1, 0.85))
		draw_rect(r, Color(0.7, 0.8, 0.9, 0.7), false, 3.0)
		draw_arc(Vector2(0, -size.y), size.x * 0.5, PI, TAU, 14, Color(0.7, 0.8, 0.9, 0.7), 3.0)
	else:
		# soft glowing passage hint
		var a := 0.12 + 0.08 * sin(t * 2.0)
		draw_rect(r, Color(1, 1, 1, a))


func _art_switch() -> void:
	draw_rect(Rect2(-8, -10, 16, 10), Color(0.4, 0.4, 0.45))
	var col := Color(0.4, 1.0, 0.5) if active else Color(1.0, 0.45, 0.3)
	draw_circle(Vector2(0, -22), 10.0, Color(0.15, 0.15, 0.2))
	draw_circle(Vector2(0, -22), 7.0, col)
	if not active:
		draw_circle(Vector2(0, -22), 13.0 + sin(t * 4.0) * 2.0, Color(col.r, col.g, col.b, 0.2))
	if order > 0:
		draw_string(ThemeDB.fallback_font, Vector2(-4, -19), str(order), HORIZONTAL_ALIGNMENT_CENTER, 12, 13, Color(0.1, 0.1, 0.1))


func _art_npc() -> void:
	var data: Dictionary = Story.NPCS.get(str(props.get("npc", "")), {})
	var col: Color = data.get("color", Color(0.6, 0.5, 0.8))
	var bob := sin(t * 2.0) * 1.0
	draw_rect(Rect2(-9, -22, 6, 22), Color(0.2, 0.2, 0.3))
	draw_rect(Rect2(3, -22, 6, 22), Color(0.2, 0.2, 0.3))
	draw_rect(Rect2(-12, -40 + bob, 24, 22), col)
	draw_rect(Rect2(-12, -40 + bob, 24, 22), Color(0.1, 0.1, 0.15), false, 2.0)
	draw_circle(Vector2(0, -46 + bob), 8.0, Color(0.95, 0.78, 0.62))
	draw_circle(Vector2(0, -46 + bob), 8.0, Color(0.1, 0.1, 0.15), false, 1.5)
	_npc_hat(str(props.get("npc", "")), bob, col)
	draw_circle(Vector2(3, -46 + bob), 1.3, Color(0.1, 0.1, 0.2))
	var p: Player = stage.player
	if p != null and absf(p.position.x - position.x) < 120.0:
		var c := Vector2(0, -66 + sin(t * 4.0) * 2.0)
		draw_circle(c, 8.0, Color(1, 1, 1, 0.9))
		draw_circle(c + Vector2(-3, 0), 1.2, Color(0.2, 0.2, 0.3))
		draw_circle(c, 1.2, Color(0.2, 0.2, 0.3))
		draw_circle(c + Vector2(3, 0), 1.2, Color(0.2, 0.2, 0.3))


func _npc_hat(id: String, bob: float, col: Color) -> void:
	match id:
		"merchant":
			draw_colored_polygon(PackedVector2Array([Vector2(-10, -50 + bob), Vector2(10, -50 + bob), Vector2(0, -62 + bob)]), Color(0.8, 0.3, 0.2))
			draw_rect(Rect2(-13, -51 + bob, 26, 3), Color(0.8, 0.3, 0.2))
		"inventor":
			draw_circle(Vector2(0, -50 + bob), 9.0, Color(0.9, 0.9, 0.6, 0.5))
			draw_rect(Rect2(-9, -50 + bob, 18, 5), Color(0.5, 0.35, 0.2))
			draw_circle(Vector2(5, -49 + bob), 3.0, Color(0.7, 0.9, 1.0, 0.8))
		"scholar":
			draw_rect(Rect2(-10, -56 + bob, 20, 5), Color(0.25, 0.25, 0.5))
			draw_line(Vector2(10, -53 + bob), Vector2(14, -44 + bob), Color(1.0, 0.9, 0.4), 2.0)
		"warrior":
			draw_colored_polygon(PackedVector2Array([Vector2(-9, -48 + bob), Vector2(9, -48 + bob), Vector2(7, -58 + bob), Vector2(-7, -58 + bob)]), Color(0.7, 0.72, 0.78))
			draw_line(Vector2(0, -58 + bob), Vector2(0, -64 + bob), Color(0.9, 0.2, 0.2), 3.0)
		_:
			draw_arc(Vector2(0, -50 + bob), 9.0, PI, TAU, 10, Color(0.3, 0.2, 0.15), 3.0)


func _art_altar() -> void:
	var gl := Color(0.7, 1.0, 1.0)
	draw_rect(Rect2(-26, -14, 52, 14), Color(0.4, 0.42, 0.5))
	draw_rect(Rect2(-18, -30, 36, 16), Color(0.5, 0.52, 0.6))
	draw_rect(Rect2(-18, -30, 36, 16), Color(0.1, 0.1, 0.15), false, 2.0)
	if not used:
		var c := Vector2(0, -50 + sin(t * 2.0) * 4.0)
		draw_circle(c, 22.0 + sin(t * 3.0) * 3.0, Color(gl.r, gl.g, gl.b, 0.22))
		var pts := PackedVector2Array([c + Vector2(0, -13), c + Vector2(9, 0), c + Vector2(0, 13), c + Vector2(-9, 0)])
		draw_colored_polygon(pts, gl)
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.1, 0.3, 0.4), 2.0)
