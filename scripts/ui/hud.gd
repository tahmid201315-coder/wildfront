extends Control
## In-game HUD: vitals, level, compass, quest tracker, toasts, interaction prompt and touch buttons.

const UI = preload("res://scripts/ui/ui_kit.gd")
const TouchControls = preload("res://scripts/ui/touch_controls.gd")
const TouchButton = preload("res://scripts/ui/touch_button.gd")
const WG = preload("res://scripts/world/world_gen.gd")
const DW = preload("res://scripts/core/data_world.gd")

signal panel_requested(name: String)
signal storage_requested(box: Node)
signal log_requested(id: String)
signal dialogue_requested(id: String)

var world: Node = null
var player: Node = null
var touch: Control
var b_attack: Control
var b_jump: Control
var b_dodge: Control
var b_interact: Control
var b_sprint: Control
var b_crouch: Control
var small_buttons: Dictionary = {}
var build_buttons: Array = []
var b_bconfirm: Control
var b_brotate: Control
var b_bremove: Control
var b_bcancel: Control
var _toasts: Array = []              # [text, kind, age]
var _t: float = 0.0
var _tracker_cache: String = ""
var _banner: String = ""
var _banner_t: float = 0.0
var _banner_sub: String = ""
var _hit_t: float = 0.0
var _last_hp: float = 100.0
var boss_name: String = ""
var boss_frac: float = 0.0
var show_boss: bool = false
var _fps_label: bool = false


func _ready() -> void:
	theme = UI.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	touch = TouchControls.new()
	add_child(touch)
	touch.look_delta.connect(func(d): if player: player.apply_look(d))
	touch.zoom_delta.connect(func(z): if player: player.apply_zoom(z))
	b_attack = _mk("strike", "", 64.0, Color(0.95, 0.4, 0.3))
	b_attack.pressed.connect(func(): if player: player.attack_down())
	b_attack.released.connect(func(): if player: player.attack_up())
	b_jump = _mk("jump", "", 50.0, Color(0.4, 0.8, 0.7))
	b_jump.pressed.connect(func(): if player: player.request_jump())
	b_dodge = _mk("dodge", "", 46.0, Color(0.5, 0.65, 0.95))
	b_dodge.pressed.connect(func(): if player: player.request_dodge())
	b_interact = _mk("act", "", 52.0, Color(0.96, 0.72, 0.28))
	b_interact.pressed.connect(func(): if player: player.interact_down())
	b_interact.released.connect(func(): if player: player.interact_up())
	b_sprint = _mk("sprint", "", 40.0, Color(0.9, 0.85, 0.4))
	b_sprint.pressed.connect(func(): if player: player.set_sprint(true))
	b_sprint.released.connect(func(): if player: player.set_sprint(false))
	b_crouch = _mk("crouch", "", 38.0, Color(0.6, 0.6, 0.75))
	b_crouch.pressed.connect(func(): if player: player.toggle_crouch())
	for def in [["pause", "pause"], ["map", "map"], ["bag", "inventory"], ["build", "craft"], ["book", "quests"]]:
		var b := _mk(def[0], "", 30.0, Color(0.5, 0.6, 0.65))
		var nm: String = def[1]
		b.pressed.connect(func(): panel_requested.emit(nm))
		small_buttons[nm] = b
	b_bconfirm = _mk("check", "Place", 60.0, Color(0.35, 0.8, 0.45))
	b_bconfirm.pressed.connect(func(): if world: world.builder.confirm())
	b_brotate = _mk("rotate", "Rotate", 46.0, Color(0.5, 0.65, 0.95))
	b_brotate.pressed.connect(func(): if world: world.builder.rotate_piece())
	b_bremove = _mk("close", "Dismantle", 46.0, Color(0.95, 0.65, 0.25))
	b_bremove.pressed.connect(func(): if world: world.builder.toggle_remove())
	b_bcancel = _mk("pause", "Done", 40.0, Color(0.7, 0.7, 0.75))
	b_bcancel.pressed.connect(func(): if world: world.builder.cancel())
	build_buttons = [b_bconfirm, b_brotate, b_bremove, b_bcancel]
	Game.notify.connect(_on_notify)
	Game.leveled_up.connect(func(lv): banner("LEVEL %d" % lv, "A skill point is waiting."))
	Game.region_entered.connect(_on_region)
	Game.settings_changed.connect(_layout)
	resized.connect(_layout)
	_layout()


func _mk(glyph: String, label: String, r: float, tint: Color) -> Control:
	var b := TouchButton.new(glyph, label, r)
	b.tint = tint
	add_child(b)
	touch.register(b)
	return b


func bind(w: Node, p: Node) -> void:
	world = w
	player = p
	p.touch = touch
	_last_hp = Game.health


func banner(text: String, sub: String = "") -> void:
	_banner = text
	_banner_sub = sub
	_banner_t = 3.2


func _on_region(id: String) -> void:
	if Game.regions_seen.size() > 1 or id != "coast":
		banner(DW.REGIONS[id]["name"].to_upper(), DW.REGIONS[id]["blurb"])


func _on_notify(text: String, kind: String) -> void:
	for t in _toasts:
		if t[0] == text:
			t[2] = 0.0
			return
	_toasts.append([text, kind, 0.0])
	if _toasts.size() > 6:
		_toasts.pop_front()
	if kind == "quest":
		Sfx.play("quest")


func _layout() -> void:
	var s := get_viewport_rect().size
	var m := UI.safe_margins(get_viewport())
	var k := float(Game.settings["btn_scale"])
	var left := bool(Game.settings["left_handed"])
	var base := Vector2(s.x - m["r"] - 150 * k, s.y - m["b"] - 150 * k)
	var sx := 1.0
	if left:
		base = Vector2(m["l"] + 150 * k, s.y - m["b"] - 150 * k)
		sx = -1.0
	touch.left_handed = left
	var place := func(b: Control, off: Vector2) -> void:
		b.radius = b.radius if b.has_meta("r0") else b.radius
		if not b.has_meta("r0"):
			b.set_meta("r0", b.radius)
		b.radius = float(b.get_meta("r0")) * k
		b.custom_minimum_size = Vector2(b.radius * 2, b.radius * 2)
		b.size = b.custom_minimum_size
		var c: Vector2 = base + Vector2(off.x * sx, off.y) * k
		b.position = c - b.size * 0.5
		b.queue_redraw()
	place.call(b_attack, Vector2(0, 0))
	place.call(b_jump, Vector2(-150, 38))
	place.call(b_dodge, Vector2(-12, -150))
	place.call(b_interact, Vector2(-160, -118))
	place.call(b_sprint, Vector2(-290, 52))
	place.call(b_crouch, Vector2(-275, -50))
	place.call(b_bconfirm, Vector2(0, 0))
	place.call(b_brotate, Vector2(-140, 30))
	place.call(b_bremove, Vector2(-20, -140))
	place.call(b_bcancel, Vector2(-150, -120))
	var names := ["pause", "map", "inventory", "craft", "quests"]
	for i in names.size():
		var b: Control = small_buttons[names[i]]
		b.radius = 30.0 * k
		b.size = Vector2(b.radius * 2, b.radius * 2)
		var x: float = (s.x - m["r"] - 40 - i * 74.0 * k) if not left else (m["l"] + 40 + i * 74.0 * k)
		if left:
			x = s.x - m["r"] - 40 - i * 74.0 * k
		b.position = Vector2(x, m["t"] + 38) - b.size * 0.5
	touch.joy_rest = Vector2(m["l"] + 190, s.y - m["b"] - 150) if not left else Vector2(s.x - m["r"] - 190, s.y - m["b"] - 150)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	for t in _toasts:
		t[2] += delta
	while not _toasts.is_empty() and _toasts[0][2] > 4.0:
		_toasts.pop_front()
	_banner_t = maxf(_banner_t - delta, 0.0)
	_hit_t = maxf(_hit_t - delta, 0.0)
	if Game.health < _last_hp - 0.5:
		_hit_t = 0.4
	_last_hp = Game.health
	var building: bool = Game.state == Game.State.BUILDING
	for b in [b_attack, b_jump, b_dodge, b_interact, b_sprint, b_crouch]:
		b.visible = not building
	for b in build_buttons:
		b.visible = building
	if player:
		var has_target: bool = player.prompt_target != null
		b_interact.enabled = has_target
		b_interact.modulate.a = 1.0 if has_target else 0.4
		b_interact.set_label(_short_prompt(player.prompt_text) if has_target else "")
		b_sprint.tint = Color(0.98, 0.85, 0.3) if player.sprint_held else Color(0.55, 0.55, 0.45)
		b_crouch.tint = Color(0.95, 0.75, 0.3) if player.crouch_on else Color(0.5, 0.5, 0.65)
		b_dodge.cooldown_frac = clampf(player.dodge_cd / 0.62, 0.0, 1.0)
		b_attack.tint = Color(0.95, 0.4, 0.3)
	queue_redraw()


func _short_prompt(t: String) -> String:
	if t.length() > 14:
		return t.substr(0, 13) + "."
	return t


func _draw() -> void:
	if player == null:
		return
	var s := get_viewport_rect().size
	var m := UI.safe_margins(get_viewport())
	var font := ThemeDB.fallback_font
	var x0: float = m["l"] + 12
	var y0: float = m["t"] + 10
	# vitals
	_bar(Vector2(x0, y0), 260, Game.health / maxf(Game.max_health, 1.0), Color(0.9, 0.3, 0.3), "health", "%d" % ceili(Game.health))
	_bar(Vector2(x0, y0 + 30), 230, Game.stamina / 100.0, Color(0.95, 0.8, 0.3), "stamina", "")
	_bar(Vector2(x0, y0 + 60), 230, Game.hunger / 100.0, Color(0.85, 0.55, 0.3), "hunger", "")
	_temp_bar(Vector2(x0, y0 + 90), 230)
	# level
	var lvy := y0 + 122
	draw_circle(Vector2(x0 + 18, lvy + 14), 18, Color(0.1, 0.14, 0.16, 0.9))
	draw_arc(Vector2(x0 + 18, lvy + 14), 18, 0, TAU, 28, UI.COL_ACCENT, 2.0, true)
	var lvs := str(Game.level)
	var lw := font.get_string_size(lvs, HORIZONTAL_ALIGNMENT_CENTER, -1, 20).x
	draw_string(font, Vector2(x0 + 18 - lw * 0.5, lvy + 21), lvs, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UI.COL_TEXT)
	var xpf := float(Game.xp) / float(maxi(Game.xp_needed(), 1))
	draw_rect(Rect2(x0 + 44, lvy + 8, 190, 10), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(x0 + 44, lvy + 8, 190 * clampf(xpf, 0, 1), 10), Color(0.5, 0.9, 0.75))
	if Game.skill_points > 0:
		draw_string(font, Vector2(x0 + 44, lvy + 38), "%d skill point%s" % [Game.skill_points, "" if Game.skill_points == 1 else "s"], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, UI.COL_ACCENT)
	# quest tracker
	_draw_tracker(Vector2(x0, lvy + 56), font)
	# compass
	_draw_compass(Vector2(s.x * 0.5, m["t"] + 26), font)
	# toasts
	var ty: float = m["t"] + 92
	for t in _toasts:
		var a := clampf(1.0 - (float(t[2]) - 3.2) / 0.8, 0.0, 1.0)
		var col := Color(1, 1, 1)
		match String(t[1]):
			"warn": col = Color(1.0, 0.6, 0.45)
			"item": col = Color(0.75, 0.95, 0.8)
			"quest": col = UI.COL_ACCENT
		var tw := font.get_string_size(String(t[0]), HORIZONTAL_ALIGNMENT_CENTER, -1, 21).x
		var rect := Rect2(s.x * 0.5 - tw * 0.5 - 14, ty - 22, tw + 28, 32)
		draw_rect(rect, Color(0.04, 0.07, 0.08, 0.7 * a))
		draw_string(font, Vector2(rect.position.x + 14, ty), String(t[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color(col.r, col.g, col.b, a))
		ty += 38
	# build hint
	if Game.state == Game.State.BUILDING and world and world.builder.active:
		var bm: Node = world.builder
		var msg: String = "Dismantle: aim at a structure" if bm.remove_mode else String(Data.structures[bm.sid]["name"])
		if not bm.valid and bm.reason != "":
			msg += "  -  " + bm.reason
		var mw := font.get_string_size(msg, HORIZONTAL_ALIGNMENT_CENTER, -1, 24).x
		var mr := Rect2(s.x * 0.5 - mw * 0.5 - 18, s.y * 0.14, mw + 36, 40)
		draw_rect(mr, Color(0.04, 0.07, 0.08, 0.8))
		draw_rect(mr, UI.COL_GOOD if bm.valid else UI.COL_BAD, false, 2.0)
		draw_string(font, Vector2(mr.position.x + 18, mr.position.y + 28), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UI.COL_TEXT)
	# interaction prompt
	if player.prompt_target != null and Game.state != Game.State.BUILDING:
		var pt: String = player.prompt_text
		var pw := font.get_string_size(pt, HORIZONTAL_ALIGNMENT_CENTER, -1, 24).x
		var pr := Rect2(s.x * 0.5 - pw * 0.5 - 18, s.y * 0.66, pw + 36, 40)
		draw_rect(pr, Color(0.04, 0.07, 0.08, 0.75))
		draw_rect(pr, Color(UI.COL_ACCENT.r, UI.COL_ACCENT.g, UI.COL_ACCENT.b, 0.8), false, 2.0)
		draw_string(font, Vector2(pr.position.x + 18, pr.position.y + 28), pt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UI.COL_TEXT)
	# banner
	if _banner_t > 0.0:
		var a2 := clampf(minf(_banner_t, 3.2 - _banner_t + 0.6) * 1.5, 0.0, 1.0)
		var bw := font.get_string_size(_banner, HORIZONTAL_ALIGNMENT_CENTER, -1, 44).x
		var by := s.y * 0.26
		draw_string_outline(font, Vector2(s.x * 0.5 - bw * 0.5, by), _banner, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, 10, Color(0, 0, 0, 0.8 * a2))
		draw_string(font, Vector2(s.x * 0.5 - bw * 0.5, by), _banner, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color(1, 0.95, 0.75, a2))
		if _banner_sub != "":
			var sw := font.get_string_size(_banner_sub, HORIZONTAL_ALIGNMENT_CENTER, -1, 21).x
			draw_string_outline(font, Vector2(s.x * 0.5 - sw * 0.5, by + 34), _banner_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, 6, Color(0, 0, 0, 0.8 * a2))
			draw_string(font, Vector2(s.x * 0.5 - sw * 0.5, by + 34), _banner_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color(0.9, 0.95, 0.95, a2))
	# boss bar
	if show_boss:
		var bw2 := minf(s.x * 0.5, 620.0)
		var bx := (s.x - bw2) * 0.5
		var byy: float = s.y - m["b"] - 46
		draw_rect(Rect2(bx - 4, byy - 4, bw2 + 8, 26), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(bx, byy, bw2 * clampf(boss_frac, 0, 1), 18), Color(0.8, 0.2, 0.2))
		draw_rect(Rect2(bx, byy, bw2, 18), Color(1, 1, 1, 0.6), false, 2.0)
		var nw := font.get_string_size(boss_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 22).x
		draw_string_outline(font, Vector2(s.x * 0.5 - nw * 0.5, byy - 10), boss_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 6, Color(0, 0, 0, 0.8))
		draw_string(font, Vector2(s.x * 0.5 - nw * 0.5, byy - 10), boss_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.85, 0.8))
	# low health vignette
	var low := 1.0 - clampf(Game.health / maxf(Game.max_health, 1.0) * 3.0, 0.0, 1.0)
	if low > 0.0 or _hit_t > 0.0:
		var va := low * (0.25 + 0.1 * sin(_t * 6.0)) + _hit_t * 0.4
		_vignette(s, va)


func _vignette(s: Vector2, a: float) -> void:
	var w := 70.0
	for i in 5:
		var f := 1.0 - float(i) / 5.0
		var c := Color(0.7, 0.05, 0.05, a * f * 0.35)
		var o := float(i) * w * 0.4
		draw_rect(Rect2(o, o, s.x - o * 2, w * 0.4), c)
		draw_rect(Rect2(o, s.y - o - w * 0.4, s.x - o * 2, w * 0.4), c)
		draw_rect(Rect2(o, o, w * 0.4, s.y - o * 2), c)
		draw_rect(Rect2(s.x - o - w * 0.4, o, w * 0.4, s.y - o * 2), c)


func _bar(pos: Vector2, w: float, f: float, col: Color, icon: String, txt: String) -> void:
	draw_rect(Rect2(pos.x, pos.y, w + 34, 24), Color(0.04, 0.07, 0.08, 0.6))
	_icon(pos + Vector2(14, 12), icon, col)
	draw_rect(Rect2(pos.x + 30, pos.y + 6, w - 6, 12), Color(0, 0, 0, 0.5))
	var fc := col
	if f < 0.25:
		fc = col.lerp(Color(1, 0.2, 0.2), 0.5 + 0.5 * sin(_t * 8.0))
	draw_rect(Rect2(pos.x + 30, pos.y + 6, (w - 6) * clampf(f, 0, 1), 12), fc)
	draw_rect(Rect2(pos.x + 30, pos.y + 6, w - 6, 12), Color(1, 1, 1, 0.35), false, 1.0)
	if txt != "":
		draw_string(ThemeDB.fallback_font, Vector2(pos.x + w + 2 - ThemeDB.fallback_font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x, pos.y + 18), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.9))


func _temp_bar(pos: Vector2, w: float) -> void:
	var f: float = Game.temperature / 100.0
	draw_rect(Rect2(pos.x, pos.y, w + 34, 24), Color(0.04, 0.07, 0.08, 0.6))
	_icon(pos + Vector2(14, 12), "temp", Color(0.9, 0.9, 0.9))
	var bx := pos.x + 30
	var bw := w - 6
	draw_rect(Rect2(bx, pos.y + 6, bw * 0.5, 12), Color(0.2, 0.45, 0.85, 0.5))
	draw_rect(Rect2(bx + bw * 0.5, pos.y + 6, bw * 0.5, 12), Color(0.9, 0.4, 0.2, 0.5))
	draw_rect(Rect2(bx + bw * 0.3, pos.y + 6, bw * 0.4, 12), Color(0.3, 0.8, 0.45, 0.45))
	var mx := bx + bw * clampf(f, 0, 1)
	var danger: bool = Game.temperature > 80.0 or Game.temperature < 20.0
	draw_rect(Rect2(mx - 3, pos.y + 2, 6, 20), Color(1, 0.4, 0.4) if danger else Color.WHITE)
	draw_rect(Rect2(bx, pos.y + 6, bw, 12), Color(1, 1, 1, 0.35), false, 1.0)


func _icon(c: Vector2, kind: String, col: Color) -> void:
	match kind:
		"health":
			draw_rect(Rect2(c.x - 3, c.y - 8, 6, 16), col)
			draw_rect(Rect2(c.x - 8, c.y - 3, 16, 6), col)
		"stamina":
			draw_colored_polygon(PackedVector2Array([c + Vector2(2, -9), c + Vector2(-6, 2), c + Vector2(-1, 2), c + Vector2(-3, 9), c + Vector2(6, -2), c + Vector2(1, -2)]), col)
		"hunger":
			draw_circle(c + Vector2(-2, 2), 6, col)
			draw_circle(c + Vector2(3, 3), 5, col.lightened(0.15))
			draw_line(c + Vector2(0, -3), c + Vector2(2, -8), Color(0.4, 0.75, 0.35), 2.0)
		"temp":
			draw_rect(Rect2(c.x - 2, c.y - 9, 4, 12), col)
			draw_circle(c + Vector2(0, 6), 5, col)


func _draw_tracker(pos: Vector2, font: Font) -> void:
	var qid: String = Quests.tracked_id
	if qid == "" or not Data.quests.has(qid):
		return
	var q: Dictionary = Data.quests[qid]
	var lines: Array = []
	for i in q["objectives"].size():
		lines.append(Quests.objective_text(qid, i))
	var w := 330.0
	var h := 34.0 + lines.size() * 24.0
	draw_rect(Rect2(pos.x, pos.y, w, h), Color(0.04, 0.07, 0.08, 0.55))
	draw_rect(Rect2(pos.x, pos.y, 4, h), UI.COL_ACCENT)
	draw_string(font, Vector2(pos.x + 14, pos.y + 24), String(q["name"]), HORIZONTAL_ALIGNMENT_LEFT, w - 20, 19, UI.COL_ACCENT)
	var y := pos.y + 48
	for i in lines.size():
		var done: bool = Quests.objective_done(q["objectives"][i])
		draw_string(font, Vector2(pos.x + 14, y), lines[i], HORIZONTAL_ALIGNMENT_LEFT, w - 24, 17, UI.COL_GOOD if done else UI.COL_TEXT)
		y += 24


func _draw_compass(center: Vector2, font: Font) -> void:
	var yaw: float = player.cam_yaw
	var w := 360.0
	draw_rect(Rect2(center.x - w * 0.5, center.y - 16, w, 32), Color(0.04, 0.07, 0.08, 0.55))
	var dirs := {"N": 0.0, "E": -PI * 0.5, "S": PI, "W": PI * 0.5}
	for k in dirs:
		var a := wrapf(float(dirs[k]) - yaw + PI, 0.0, TAU) - PI
		_compass_mark(center, a, k, font, w, Color(1, 0.9, 0.7), 20)
	for k in ["NE", "SE", "SW", "NW"]:
		var ang: float = {"NE": -PI * 0.25, "SE": -PI * 0.75, "SW": PI * 0.75, "NW": PI * 0.25}[k]
		var a2 := wrapf(float(ang) - yaw + PI, 0.0, TAU) - PI
		_compass_mark(center, a2, "", font, w, Color(1, 1, 1, 0.5), 14)
	# tracked marker
	var mp: Variant = null
	if Quests.tracked_id != "":
		var mk := String(Data.quests[Quests.tracked_id].get("marker", ""))
		if mk != "" and Data.sites.has(mk):
			mp = Data.sites[mk]["pos"]
	if mp is Vector2:
		var d: Vector2 = mp - Vector2(player.global_position.x, player.global_position.z)
		var ang2 := atan2(-d.x, -d.y)
		var a3 := wrapf(ang2 - yaw + PI, 0.0, TAU) - PI
		var px := center.x + clampf(a3 / (PI * 0.5), -1.0, 1.0) * (w * 0.5 - 8)
		draw_colored_polygon(PackedVector2Array([Vector2(px, center.y - 14), Vector2(px - 7, center.y - 26), Vector2(px + 7, center.y - 26)]), UI.COL_ACCENT)
	if Game.waypoint != null:
		var wd: Vector2 = Vector2(Game.waypoint) - Vector2(player.global_position.x, player.global_position.z)
		var wa := wrapf(atan2(-wd.x, -wd.y) - yaw + PI, 0.0, TAU) - PI
		var wx := center.x + clampf(wa / (PI * 0.5), -1.0, 1.0) * (w * 0.5 - 8)
		draw_colored_polygon(PackedVector2Array([Vector2(wx, center.y - 14), Vector2(wx - 7, center.y - 26), Vector2(wx + 7, center.y - 26)]), Color(1, 0.4, 0.4))
		var dtxt := "%d m" % int(wd.length())
		draw_string(font, Vector2(wx - 18, center.y + 36), dtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.6, 0.6))
	draw_line(Vector2(center.x, center.y + 12), Vector2(center.x, center.y + 20), Color(1, 1, 1, 0.8), 2.0)
	var reg := String(DW.REGIONS[player.current_region]["name"])
	var rw := font.get_string_size(reg, HORIZONTAL_ALIGNMENT_CENTER, -1, 17).x
	draw_string(font, Vector2(center.x - rw * 0.5, center.y + 38), reg, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 1, 1, 0.8))


func _compass_mark(center: Vector2, a: float, txt: String, font: Font, w: float, col: Color, fs: int) -> void:
	if absf(a) > PI * 0.5:
		return
	var px := center.x + (a / (PI * 0.5)) * (w * 0.5 - 8)
	if txt == "":
		draw_line(Vector2(px, center.y - 5), Vector2(px, center.y + 5), col, 2.0)
	else:
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string(font, Vector2(px - tw * 0.5, center.y + 7), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
