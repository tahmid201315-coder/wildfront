class_name Hud
extends CanvasLayer
## In-game overlay: bars, resources, boss bar, toasts, prompts, quest tracker, dialogue and NPC/shop panels.

var stage: Stage
var draw_c: Control
var theme_root: Control
var toasts: Array = []              # {text, kind, t}
var boss_vis := false
var boss_name := ""
var boss_frac := 1.0
var boss_shown := 0.0
var banner_t := 0.0
var banner_text := ""
var hurt_flash := 0.0
var _hp_lag := 1.0

# dialogue
var dlg: PanelContainer
var dlg_name: Label
var dlg_text: Label
var dlg_hint: Label
var _lines: Array = []
var _li := 0
var _done: Callable = Callable()
var _type_t := 0.0
var dlg_open := false
var npc_panel: PanelContainer = null
var npc_open := false
var info_text := ""                 # last text shown (tests)


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme_root = Control.new()
	theme_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	theme_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme_root.theme = UI.make_theme(int(Game.settings.get("text_size", 1)))
	add_child(theme_root)
	draw_c = Control.new()
	draw_c.set_anchors_preset(Control.PRESET_FULL_RECT)
	draw_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw_c.draw.connect(_draw_hud)
	theme_root.add_child(draw_c)
	_build_dialogue()
	Game.toast.connect(_on_toast)
	Game.boss_changed.connect(_on_boss)
	Game.state_changed.connect(func(_s: int) -> void: theme_root.theme = UI.make_theme(int(Game.settings.get("text_size", 1))))


func attach(s: Stage) -> void:
	stage = s
	s.hud = self
	s.room_loaded.connect(_on_room)
	s.player.hurt_signal.connect(func(_a: float) -> void: hurt_flash = 0.5)


func _on_room(_id: String) -> void:
	banner_text = stage.data.title
	banner_t = 3.0


func _on_toast(text: String, kind: String) -> void:
	toasts.append({"text": text, "kind": kind, "t": 3.2})
	if toasts.size() > 5:
		toasts.pop_front()


func _on_boss(v: bool, n: String, f: float) -> void:
	boss_vis = v
	boss_name = n
	boss_frac = f


func _process(dt: float) -> void:
	for t in toasts:
		t["t"] -= dt
	while not toasts.is_empty() and toasts[0]["t"] <= 0.0:
		toasts.pop_front()
	banner_t = maxf(banner_t - dt, 0.0)
	hurt_flash = maxf(hurt_flash - dt * 2.0, 0.0)
	boss_shown = move_toward(boss_shown, 1.0 if boss_vis else 0.0, dt * 2.0)
	_hp_lag = move_toward(_hp_lag, Game.hp / maxf(Game.max_hp(), 1.0), dt * 0.6)
	if dlg_open and dlg_text.visible_characters < dlg_text.text.length():
		_type_t += dt * 70.0
		dlg_text.visible_characters = mini(int(_type_t), dlg_text.text.length())
	draw_c.queue_redraw()
	if stage != null and stage.player != null:
		pass


# ------------------------------------------------------------------ drawing
func _bar(r: Rect2, frac: float, col: Color, back: Color = Color(0.05, 0.06, 0.12, 0.85), lag: float = -1.0) -> void:
	draw_c.draw_rect(r.grow(3.0), Color(0.02, 0.03, 0.07, 0.9))
	draw_c.draw_rect(r, back)
	if lag >= 0.0:
		draw_c.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(lag, 0, 1), r.size.y)), Color(1, 1, 1, 0.35))
	draw_c.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0, 1), r.size.y)), col)
	draw_c.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0, 1), r.size.y * 0.4)), Color(1, 1, 1, 0.18))


func _txt(p: Vector2, s: String, size: int = 20, col: Color = UI.TEXT, align: int = HORIZONTAL_ALIGNMENT_LEFT, w: float = -1.0) -> void:
	var f := ThemeDB.fallback_font
	draw_c.draw_string(f, p + Vector2(1.5, 1.5), s, align, w, size, Color(0, 0, 0, 0.8))
	draw_c.draw_string(f, p, s, align, w, size, col)


func _draw_hud() -> void:
	if stage == null or Game.state == Game.State.TITLE:
		return
	var vp := draw_c.size
	var sc: float = float(Game.settings.get("ui_scale", 1.0))
	draw_c.draw_set_transform(Vector2.ZERO, 0.0, Vector2(sc, sc))
	vp /= sc
	# screen flash from the stage
	if stage.flash_a > 0.01:
		draw_c.draw_rect(Rect2(Vector2.ZERO, vp), Color(stage.flash_color.r, stage.flash_color.g, stage.flash_color.b, stage.flash_a))
	if hurt_flash > 0.0 and not Game.settings.get("flash_reduce", false):
		draw_c.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.8, 0.05, 0.05, hurt_flash * 0.22))
	# health / magic
	var hpf := Game.hp / maxf(Game.max_hp(), 1.0)
	var low := hpf < 0.3
	_bar(Rect2(24, 22, 28 + Game.max_hp() * 1.6, 18), hpf, Color(1, 0.3, 0.3) if low else Color(0.85, 0.25, 0.3), Color(0.15, 0.05, 0.08, 0.85), _hp_lag)
	_txt(Vector2(30, 38), "%d / %d" % [ceili(Game.hp), int(Game.max_hp())], 14, Color.WHITE)
	_bar(Rect2(24, 48, 28 + Game.max_mp() * 1.6, 11), Game.mp / maxf(Game.max_mp(), 1.0), Color(0.35, 0.6, 1.0))
	for i in Game.max_heals():
		var c := Color(0.5, 1.0, 0.65) if i < Game.heals_left else Color(0.2, 0.28, 0.25)
		var cx := 34.0 + i * 24.0
		draw_c.draw_circle(Vector2(cx, 80), 9.0, Color(0.02, 0.05, 0.05))
		draw_c.draw_circle(Vector2(cx, 80), 7.0, c)
	# resources top-right
	var x := vp.x - 24.0

	draw_c.draw_string(ThemeDB.fallback_font, Vector2(x - 300, 34), "Shards %d" % Game.shards, HORIZONTAL_ALIGNMENT_RIGHT, 300, 22, UI.GOLD)
	draw_c.draw_string(ThemeDB.fallback_font, Vector2(x - 300, 58), "Dust %d   Fragments %d/7" % [Game.dust, Game.fragments], HORIZONTAL_ALIGNMENT_RIGHT, 300, 16, UI.DIM)
	draw_c.draw_string(ThemeDB.fallback_font, Vector2(x - 300, 80), "Lv %d  XP %d/%d" % [Game.level, Game.xp, Game.xp_needed()], HORIZONTAL_ALIGNMENT_RIGHT, 300, 14, UI.DIM)
	# quest tracker
	var qy := 112.0
	for id in Game.quests:
		if Game.quests[id] == "active":
			var q: Dictionary = Story.QUESTS[id]
			draw_c.draw_string(ThemeDB.fallback_font, Vector2(x - 300, qy), "%s  %d/%d" % [q["title"], int(Game.quest_progress.get(id, 0)), int(q["count"])], HORIZONTAL_ALIGNMENT_RIGHT, 300, 15, Color(0.7, 0.9, 1.0))
			qy += 20.0
			if qy > 180.0:
				break
	# boss bar
	if boss_shown > 0.01:
		var bw := minf(vp.x * 0.6, 620.0)
		var bx := (vp.x - bw) * 0.5
		var by := 28.0 - (1.0 - boss_shown) * 60.0
		_bar(Rect2(bx, by + 20, bw, 16), boss_frac, Color(0.95, 0.35, 0.25), Color(0.2, 0.05, 0.05, 0.9))
		_txt(Vector2(bx, by + 14), boss_name, 22, Color(1, 0.9, 0.7), HORIZONTAL_ALIGNMENT_CENTER, bw)
	# room banner
	if banner_t > 0.0:
		var a := clampf(minf(banner_t, 3.0 - banner_t + 0.4), 0.0, 1.0)
		_txt(Vector2(0, vp.y * 0.22), banner_text, 30, Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, vp.x)
	# interaction prompt
	if Game.state == Game.State.PLAY and stage.player != null and stage.player.alive and not dlg_open:
		var pr := stage.nearest_prompt()
		if not pr.is_empty():
			var sp: Vector2 = stage.get_viewport().get_canvas_transform() * (pr["pos"] + Vector2(0, -78))
			var tw := 30.0 + str(pr["text"]).length() * 10.0
			draw_c.draw_rect(Rect2(sp.x / sc - tw * 0.5, sp.y / sc - 20, tw, 30), Color(0.04, 0.06, 0.14, 0.85))
			_txt(Vector2(sp.x / sc - tw * 0.5, sp.y / sc), "[E] " + str(pr["text"]), 17, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER, tw)
	# toasts
	var ty := vp.y - 150.0
	for t in toasts:
		var a2 := clampf(t["t"], 0.0, 0.5) * 2.0
		var col := UI.TEXT
		match t["kind"]:
			"good", "level": col = Color(0.7, 1.0, 0.7)
			"quest": col = Color(0.7, 0.9, 1.0)
			"item", "ability": col = UI.GOLD
		col.a = a2
		_txt(Vector2(0, ty), t["text"], 20, col, HORIZONTAL_ALIGNMENT_CENTER, vp.x)
		ty -= 26.0
	draw_c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ------------------------------------------------------------------ dialogue
func _build_dialogue() -> void:
	dlg = PanelContainer.new()
	dlg.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	dlg.offset_left = 90
	dlg.offset_right = -90
	dlg.offset_top = -210
	dlg.offset_bottom = -30
	dlg.visible = false
	dlg.mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new()
	dlg.add_child(v)
	dlg_name = UI.label("", 22, UI.GOLD)
	v.add_child(dlg_name)
	dlg_text = UI.label("", 24)
	dlg_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(dlg_text)
	dlg_hint = UI.label("Tap or press Interact to continue", 14, UI.DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	v.add_child(dlg_hint)
	dlg.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			advance())
	theme_root.add_child(dlg)


## lines: Array of strings. Strings of the form `NAME: "text"` show NAME as the speaker.
func show_lines(lines: Array, done: Callable = Callable(), title: String = "") -> void:
	if lines.is_empty():
		if done.is_valid():
			done.call()
		return
	_lines = lines.duplicate()
	_li = 0
	_done = done
	dlg_name.text = title
	dlg_open = true
	dlg.visible = true
	if Game.state == Game.State.PLAY:
		Game.push_state(Game.State.DIALOGUE)
	_show_line()


func show_text(title: String, text: String) -> void:
	show_lines([text], Callable(), title)


func _show_line() -> void:
	var s: String = str(_lines[_li])
	var colon := s.find(":")
	if colon > 0 and colon < 14 and s.substr(0, colon) == s.substr(0, colon).to_upper():
		dlg_name.text = s.substr(0, colon).capitalize()
		s = s.substr(colon + 1).strip_edges()
	dlg_text.text = s
	info_text = s
	dlg_text.visible_characters = 0
	_type_t = 0.0


func advance() -> void:
	if not dlg_open:
		return
	if dlg_text.visible_characters < dlg_text.text.length():
		dlg_text.visible_characters = dlg_text.text.length()
		_type_t = 99999.0
		return
	_li += 1
	if _li >= _lines.size():
		close_dialogue()
	else:
		_show_line()


func close_dialogue() -> void:
	dlg_open = false
	dlg.visible = false
	var cb := _done
	_done = Callable()
	if Game.state == Game.State.DIALOGUE:
		Game.pop_state()
	if cb.is_valid():
		cb.call()


func _unhandled_input(e: InputEvent) -> void:
	if dlg_open and (e.is_action_pressed("interact") or e.is_action_pressed("jump") or e.is_action_pressed("light") or e.is_action_pressed("ui_accept")):
		advance()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ NPC panel (talk, quests, shop, upgrades)
var _npc_id := ""
var _npc_talk_i := 0


func open_npc(id: String) -> void:
	_npc_id = id
	npc_open = true
	if Game.state == Game.State.PLAY:
		Game.push_state(Game.State.DIALOGUE)
	_rebuild_npc("")


func close_npc() -> void:
	npc_open = false
	if npc_panel != null:
		npc_panel.queue_free()
		npc_panel = null
	if Game.state == Game.State.DIALOGUE:
		Game.pop_state()


func _rebuild_npc(msg: String) -> void:
	if npc_panel != null:
		npc_panel.queue_free()
	var n: Dictionary = Story.NPCS[_npc_id]
	npc_panel = PanelContainer.new()
	npc_panel.set_anchors_preset(Control.PRESET_CENTER)
	npc_panel.custom_minimum_size = Vector2(760, 0)
	npc_panel.position = Vector2(260, 90)
	var v := VBoxContainer.new()
	npc_panel.add_child(v)
	v.add_child(UI.label(n["name"], 28, n["color"]))
	v.add_child(UI.label(msg if msg != "" else Story.npc_line(_npc_id, _npc_talk_i), 22))
	var first: Control = null
	for qid in Quests.available_for(_npc_id):
		var q: Dictionary = Story.QUESTS[qid]
		var st := Quests.status(qid)
		var b: Button
		if st == "new":
			b = UI.button("Quest: %s  -  %s" % [q["title"], q["desc"]], func() -> void:
				Quests.accept(qid)
				_rebuild_npc("Good luck out there."))
		elif st == "done":
			b = UI.button("Claim reward: %s (%s)" % [q["title"], Quests.reward_text(q["reward"])], func() -> void:
				Quests.claim(qid)
				_rebuild_npc("Well earned."))
		else:
			b = UI.button("%s: %d/%d" % [q["title"], int(Game.quest_progress.get(qid, 0)), int(q["count"])], func() -> void:
				_rebuild_npc("Keep at it."))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		v.add_child(b)
		if first == null:
			first = b
	if _npc_id == "merchant":
		for sid in Game.SHOP:
			var item: Dictionary = Game.SHOP[sid]
			var why := Game.shop_can_buy(sid)
			var b2 := UI.button("%s - %s  [%d shards]%s" % [item["name"], item["desc"], Game.shop_price(sid), ("  (" + why + ")" if why != "" else "")], func() -> void:
				if Game.shop_buy(sid):
					Sfx.play("pickup")
					_rebuild_npc("Pleasure doing business!")
				else:
					Sfx.play("deny")
					_rebuild_npc(Game.shop_can_buy(sid) + "."))
			b2.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b2.disabled = false
			v.add_child(b2)
			if first == null:
				first = b2
	if _npc_id == "inventor":
		v.add_child(UI.label("Aether Dust: %d" % Game.dust, 18, UI.GOLD))
		var any := false
		for eid in Game.owned:
			any = true
			var why2 := Game.upgrade_can(eid)
			var b3 := UI.button("Upgrade %s (Lv %d/%d)  [%d dust]%s" % [Defs.EQUIPMENT[eid]["name"], int(Game.equip_lv.get(eid, 0)), Game.MAX_UPGRADE, Game.upgrade_cost(eid), ("  - " + why2 if why2 != "" else "")], func() -> void:
				if Game.upgrade_equipment(eid):
					Sfx.play("ability")
					_rebuild_npc("Shiny! Stronger now.")
				else:
					Sfx.play("deny")
					_rebuild_npc(Game.upgrade_can(eid) + "."))
			b3.alignment = HORIZONTAL_ALIGNMENT_LEFT
			v.add_child(b3)
			if first == null:
				first = b3
		if not any:
			v.add_child(UI.label("Bring me equipment to upgrade!", 18, UI.DIM))
	var talk := UI.button("Talk", func() -> void:
		_npc_talk_i += 1
		_rebuild_npc(""))
	v.add_child(talk)
	var leave := UI.button("Leave", close_npc)
	v.add_child(leave)
	theme_root.add_child(npc_panel)
	var f: Control = first if first != null else talk
	UI.focus(f)
