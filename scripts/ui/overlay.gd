class_name Overlay
extends CanvasLayer
## Full-screen overlays: the white-light launch intro, the "Loading..." screen and the small "Saving..." indicator.

var c: Control
var t := 0.0
var mode := ""            # "", "intro", "loading"
var loading_text := "Loading"
var intro_len := 2.6
var save_t := 0.0
var _stars: Array = []
var instant: bool = false   # headless runs skip all delays
signal intro_done


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	instant = DisplayServer.get_name() == "headless"
	c = Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(_draw_all)
	c.gui_input.connect(func(e: InputEvent) -> void:
		if mode == "intro" and (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
			end_intro())
	add_child(c)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 40:
		_stars.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(0.5, 1.8)))
	Game.saved.connect(func() -> void: save_t = 1.1)


func play_intro() -> void:
	if instant:
		intro_done.emit()
		return
	mode = "intro"
	t = 0.0
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.queue_redraw()


func end_intro() -> void:
	if mode != "intro":
		return
	mode = ""
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.queue_redraw()
	intro_done.emit()


## Shows the loading screen, waits a moment so it is actually seen and drawn, runs `work`, then hides it.
func with_loading(text: String, work: Callable) -> void:
	loading_text = text
	if instant:
		work.call()
		return
	mode = "loading"
	t = 0.0
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	for i in 3:
		await get_tree().process_frame
	await get_tree().create_timer(0.25, true).timeout
	work.call()
	await get_tree().create_timer(0.45, true).timeout
	mode = ""
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.queue_redraw()


func _process(dt: float) -> void:
	if mode == "intro":
		t += dt
		if t >= intro_len:
			end_intro()
	elif mode == "loading":
		t += dt
	if save_t > 0.0:
		save_t -= dt
	if mode != "" or save_t > 0.0 or c.get_meta("dirty", false):
		c.queue_redraw()
		c.set_meta("dirty", save_t > 0.0)


func _draw_all() -> void:
	var vp := c.get_viewport_rect().size
	var mid := vp * 0.5
	var font := ThemeDB.fallback_font
	if mode == "intro":
		# a white light blooms, resolves into a star and the title, then fades to reveal the menu
		var u := t / intro_len
		var white := 1.0 - smoothstep(0.35, 0.95, u)
		c.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.04, 0.05, 0.14, 1.0 - smoothstep(0.7, 1.0, u)))
		var bloom := smoothstep(0.0, 0.3, u) * (1.0 - smoothstep(0.55, 1.0, u))
		for i in 6:
			var r: float = lerpf(40.0, vp.x * 0.7, bloom) * (1.0 - i * 0.14)
			c.draw_circle(mid, r, Color(1, 1, 1, 0.16 * bloom + 0.04))
		c.draw_rect(Rect2(Vector2.ZERO, vp), Color(1, 1, 1, white * 0.9))
		var ta := smoothstep(0.35, 0.6, u) * (1.0 - smoothstep(0.85, 1.0, u))
		c.draw_string(font, mid + Vector2(-300, -10), "PROJECT STARFALL", HORIZONTAL_ALIGNMENT_CENTER, 600, 54, Color(0.1, 0.15, 0.35, ta * (1.0 if white > 0.3 else 0.0)) if white > 0.3 else Color(1.0, 0.9, 0.55, ta))
		c.draw_circle(mid + Vector2(0, -90), 14.0 + 4.0 * sin(t * 6.0), Color(1.0, 0.95, 0.7, ta))
	elif mode == "loading":
		c.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.03, 0.04, 0.1, 1.0))
		for s in _stars:
			var tw := 0.5 + 0.5 * sin(t * s.z * 2.0 + s.x * 30.0)
			c.draw_circle(Vector2(s.x * vp.x, s.y * vp.y), s.z, Color(1, 1, 1, 0.2 + 0.6 * tw))
		var dots := ".".repeat(int(t * 3.0) % 4)
		c.draw_string(font, mid + Vector2(-200, 10), loading_text + dots, HORIZONTAL_ALIGNMENT_CENTER, 400, 36, Color(0.93, 0.96, 1.0))
		for i in 7:
			var a := t * 2.5 + TAU * i / 7.0
			c.draw_circle(mid + Vector2(0, 70) + Vector2.from_angle(a) * 26.0, 5.0, Color.from_hsv(float(i) / 7.0, 0.5, 1.0, 0.9))
		c.draw_string(font, Vector2(0, vp.y - 40), "Tip: " + _tip(), HORIZONTAL_ALIGNMENT_CENTER, vp.x, 20, Color(0.6, 0.68, 0.82))
	if save_t > 0.0 and mode != "intro":
		var a2 := clampf(save_t / 0.3, 0.0, 1.0)
		var p := Vector2(vp.x - 230, 24)
		c.draw_rect(Rect2(p, Vector2(200, 40)), Color(0.05, 0.08, 0.18, 0.85 * a2))
		c.draw_circle(p + Vector2(22, 20), 6.0 + sin(t * 10.0 + save_t * 10.0), Color(1.0, 0.9, 0.5, a2))
		c.draw_string(font, p + Vector2(40, 27), "Saving...", HORIZONTAL_ALIGNMENT_LEFT, 150, 22, Color(0.93, 0.96, 1.0, a2))


func _tip() -> String:
	var tips := ["Dodge through attacks: you cannot be hit mid-roll.", "Bosses glow before they strike. Learn the telegraph.", "Starshrines restore health and set your respawn.",
		"Stasis Pulse freezes hazards and stuns guardians.", "Fill all four equipment slots for a set bonus.", "Elite enemies drop four times the shards."]
	return tips[int(Time.get_ticks_msec() / 2500) % tips.size()]
