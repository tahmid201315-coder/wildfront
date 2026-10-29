class_name Cutscene
extends CanvasLayer
## Skippable story cutscenes: procedural scene art with typewriter subtitles. Advance with interact/jump/click, skip with the button.

signal finished(id: String)

var c: Control
var theme_root: Control
var id: String = ""
var lines: Array = []
var li := 0
var shown := 0.0
var t := 0.0
var active := false
var text_label: Label
var skip_btn: Button
var hint: Label
var _stars: Array = []
var lines_seen: int = 0


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	theme_root = Control.new()
	theme_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	theme_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme_root.theme = UI.make_theme(int(Game.settings.get("text_size", 1)))
	add_child(theme_root)
	c = Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.draw.connect(_draw_scene)
	c.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed or e is InputEventScreenTouch and e.pressed:
			advance())
	theme_root.add_child(c)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 80:
		_stars.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(0.5, 2.0)))
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	p.offset_left = 80
	p.offset_right = -80
	p.offset_top = -190
	p.offset_bottom = -40
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme_root.add_child(p)
	text_label = UI.label("", 26)
	p.add_child(text_label)
	hint = UI.label("Tap / press E to continue", 16, UI.DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.position = Vector2(-340, -34)
	theme_root.add_child(hint)
	skip_btn = UI.button("Skip", skip, 130, 48)
	skip_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip_btn.position = Vector2(-160, 20)
	theme_root.add_child(skip_btn)


func play(cid: String) -> bool:
	if not Story.CUTSCENES.has(cid):
		finished.emit(cid)
		return false
	id = cid
	lines = Story.CUTSCENES[cid]
	li = 0
	shown = 0.0
	t = 0.0
	lines_seen = 0
	active = true
	visible = true
	Game.push_state(Game.State.CUTSCENE)
	_set_text()
	UI.focus(skip_btn)
	return true


func _set_text() -> void:
	text_label.text = str(lines[li]["text"])
	text_label.visible_characters = 0
	shown = 0.0


func _process(dt: float) -> void:
	if not active:
		return
	t += dt
	shown += dt * 55.0
	text_label.visible_characters = int(shown)
	c.queue_redraw()


func advance() -> void:
	if not active:
		return
	if shown < float(text_label.text.length()):
		shown = 9999.0
		text_label.visible_characters = -1
		return
	lines_seen += 1
	li += 1
	if li >= lines.size():
		_end()
	else:
		_set_text()


func skip() -> void:
	if active:
		_end()


func _end() -> void:
	active = false
	visible = false
	Game.seen_cutscenes[id] = true
	Game.pop_state()
	finished.emit(id)


func _unhandled_input(e: InputEvent) -> void:
	if active and (e.is_action_pressed("interact") or e.is_action_pressed("jump") or e.is_action_pressed("ui_accept")):
		advance()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ art
func _draw_scene() -> void:
	if not active:
		return
	var vp := c.get_viewport_rect().size
	var scene: String = str(lines[li].get("scene", "night"))
	var top := Color(0.03, 0.04, 0.12)
	var bot := Color(0.1, 0.12, 0.3)
	match scene:
		"dawn": top = Color(0.3, 0.45, 0.8); bot = Color(1.0, 0.8, 0.6)
		"eclipse", "architect": top = Color(0.04, 0.0, 0.08); bot = Color(0.25, 0.05, 0.25)
		"ruins": top = Color(0.1, 0.18, 0.12); bot = Color(0.25, 0.4, 0.25)
		"light": top = Color(0.2, 0.2, 0.4); bot = Color(1.0, 0.95, 0.7)
		"fragment": top = Color(0.05, 0.08, 0.2); bot = Color(0.2, 0.3, 0.5)
	for i in 20:
		var u := float(i) / 20.0
		c.draw_rect(Rect2(0, vp.y * u, vp.x, vp.y / 20.0 + 1.0), top.lerp(bot, u))
	for s in _stars:
		var tw := 0.5 + 0.5 * sin(t * s.z + s.x * 30.0)
		c.draw_circle(Vector2(s.x * vp.x, s.y * vp.y * 0.7), s.z, Color(1, 1, 1, (0.2 + 0.6 * tw) * (0.3 if scene == "dawn" else 1.0)))
	var mid := Vector2(vp.x * 0.5, vp.y * 0.36)
	match scene:
		"night":
			c.draw_circle(mid, 70, Color(1.0, 0.92, 0.6, 0.15))
			c.draw_circle(mid, 40, Color(1.0, 0.95, 0.75))
		"shatter":
			for i in 7:
				var a := TAU * i / 7.0 + 0.3
				var d := 30.0 + minf(t, 6.0) * 40.0
				var p := mid + Vector2.from_angle(a) * d
				var col := Color.from_hsv(float(i) / 7.0, 0.5, 1.0)
				c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -16), p + Vector2(11, 0), p + Vector2(0, 16), p + Vector2(-11, 0)]), col)
				c.draw_line(mid, p, Color(1, 1, 1, 0.15), 2.0)
		"fragment":
			var pulse := 1.0 + 0.1 * sin(t * 4.0)
			c.draw_circle(mid, 60 * pulse, Color(0.6, 0.9, 1.0, 0.2))
			c.draw_colored_polygon(PackedVector2Array([mid + Vector2(0, -34), mid + Vector2(22, 0), mid + Vector2(0, 34), mid + Vector2(-22, 0)]), Color(0.8, 1.0, 1.0))
		"ruins", "keepers":
			for i in 7:
				var x := vp.x * (0.12 + 0.76 * i / 6.0)
				c.draw_rect(Rect2(x - 18, vp.y * 0.25, 36, vp.y * 0.4), Color(0.2, 0.25, 0.22))
				c.draw_circle(Vector2(x, vp.y * 0.25), 22, Color(0.25, 0.3, 0.26))
				c.draw_circle(Vector2(x, vp.y * 0.3), 5, Color.from_hsv(float(i) / 7.0, 0.5, 1.0, 0.5 + 0.4 * sin(t * 2.0 + i)))
		"eclipse":
			c.draw_circle(mid, 80, Color(0.02, 0.0, 0.05))
			for i in 24:
				var a2 := TAU * i / 24.0 + t * 0.2
				c.draw_line(mid + Vector2.from_angle(a2) * 84, mid + Vector2.from_angle(a2) * (110 + 20 * sin(t * 2.0 + i)), Color(1.0, 0.5, 0.9, 0.7), 3.0)
		"architect":
			c.draw_circle(mid, 90, Color(1.0, 0.4, 0.9, 0.12))
			c.draw_rect(Rect2(mid.x - 24, mid.y - 70, 48, 150), Color(0.05, 0.02, 0.1))
			c.draw_circle(mid + Vector2(0, -80), 22, Color(0.05, 0.02, 0.1))
			c.draw_circle(mid + Vector2(0, -80), 8, Color(1.0, 0.85, 0.5))
		"light":
			for i in 14:
				var a3 := TAU * i / 14.0 + t * 0.3
				c.draw_line(mid, mid + Vector2.from_angle(a3) * 400, Color(1, 1, 0.8, 0.18), 18.0)
			c.draw_circle(mid, 50, Color(1, 1, 0.9))
		"dawn":
			c.draw_circle(Vector2(vp.x * 0.5, vp.y * 0.55 - minf(t, 8.0) * 14.0), 70, Color(1.0, 0.95, 0.7))
		"kael":
			pass
	# ground and Kael's silhouette on most scenes
	var gy := vp.y * 0.66
	var pts := PackedVector2Array([Vector2(0, vp.y), Vector2(0, gy)])
	for x in range(0, int(vp.x) + 40, 40):
		pts.append(Vector2(x, gy + sin(x * 0.012) * 14.0))
	pts.append(Vector2(vp.x, vp.y))
	c.draw_colored_polygon(pts, Color(0.02, 0.05, 0.08) if scene != "dawn" else Color(0.15, 0.35, 0.2))
	if scene in ["kael", "night", "dawn", "fragment", "light", "shatter"]:
		var k := Vector2(vp.x * (0.3 if scene != "kael" else 0.5), gy - 4 + sin(8.0) * 0)
		var col2 := Color(0.02, 0.02, 0.06) if scene != "dawn" else Color(0.1, 0.12, 0.2)
		c.draw_rect(Rect2(k.x - 10, k.y - 52, 20, 40), col2)
		c.draw_circle(k + Vector2(0, -62), 11, col2)
		c.draw_rect(Rect2(k.x - 12, k.y - 12, 24, 12), col2)
		c.draw_circle(k + Vector2(0, -32), 5 + sin(t * 3.0), Color(0.7, 1.0, 1.0, 0.9))
