extends CanvasLayer
## In-game HUD, touch controls and all gameplay panels.

const UI = preload("res://scripts/ui/ui_kit.gd")
const TouchControls = preload("res://scripts/ui/touch_controls.gd")
const TouchButton = preload("res://scripts/ui/touch_button.gd")
const InventoryPanel = preload("res://scripts/ui/inventory_panel.gd")
const JournalPanel = preload("res://scripts/ui/journal_panel.gd")
const MapPanel = preload("res://scripts/ui/map_panel.gd")
const SettingsPanel = preload("res://scripts/ui/settings_panel.gd")
const PauseMenu = preload("res://scripts/ui/pause_menu.gd")
const Panels = preload("res://scripts/ui/station_panels.gd")

var world: Node = null
var player: Node = null
var root: Control
var touch: Control

var btn_jump: Control
var btn_act: Control
var btn_strike: Control
var btn_ability: Control
var btn_build: Control
var btn_pause: Control
var btn_map: Control
var btn_pack: Control
var btn_journal: Control
var btn_place: Control
var btn_rotate: Control
var btn_cancel: Control
var btn_hint: Control

var bars: Control
var compass: Control
var quest_box: PanelContainer
var quest_label: Label
var hint_box: PanelContainer
var hint_label: Label
var prompt_label: Label
var comp_label: Label
var build_label: Label
var boss_box: VBoxContainer
var boss_name: Label
var boss_bar: ProgressBar
var toast_box: VBoxContainer
var defeat_overlay: Control

var inventory_panel: Control
var journal_panel: Control
var map_panel: Control
var pause_menu: Control
var settings_panel: Control
var confirm: Control
var lore_panel: Control
var chest_panel: Control
var plot_panel: Control
var rest_panel: Control
var build_menu: Control

var _t: float = 0.0
var _last_yaw: float = 999.0


func setup(p_world: Node) -> void:
	world = p_world
	player = world.player
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.theme = UI.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	touch = TouchControls.new()
	root.add_child(touch)
	touch.look_delta.connect(player.apply_look)
	touch.zoom_delta.connect(player.apply_zoom)
	player.touch = touch

	bars = StatBars.new()
	root.add_child(bars)
	compass = Compass.new()
	compass.hud = self
	root.add_child(compass)

	quest_box = PanelContainer.new()
	quest_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quest_label = UI.label("", 20, UI.COL_TEXT, true)
	quest_label.custom_minimum_size.x = 380
	quest_box.add_child(quest_label)
	root.add_child(quest_box)

	hint_box = PanelContainer.new()
	hint_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_label = UI.label("", 19, Color(1.0, 0.9, 0.6), true)
	hint_label.custom_minimum_size.x = 380
	hint_box.add_child(hint_label)
	root.add_child(hint_box)

	prompt_label = UI.label("", 24, Color.WHITE)
	prompt_label.add_theme_color_override("font_outline_color", Color.BLACK)
	prompt_label.add_theme_constant_override("outline_size", 8)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	prompt_label.custom_minimum_size = Vector2(420, 0)
	root.add_child(prompt_label)

	comp_label = UI.label("", 19, UI.COL_TEXT)
	comp_label.add_theme_color_override("font_outline_color", Color.BLACK)
	comp_label.add_theme_constant_override("outline_size", 6)
	root.add_child(comp_label)

	build_label = UI.label("", 24, Color.WHITE)
	build_label.add_theme_color_override("font_outline_color", Color.BLACK)
	build_label.add_theme_constant_override("outline_size", 8)
	build_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	build_label.custom_minimum_size = Vector2(600, 0)
	root.add_child(build_label)

	boss_box = VBoxContainer.new()
	boss_box.custom_minimum_size = Vector2(420, 0)
	boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_name = UI.label("", 22, Color(1, 0.7, 0.4))
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_bar = ProgressBar.new()
	boss_bar.custom_minimum_size = Vector2(420, 20)
	boss_bar.show_percentage = false
	boss_bar.add_theme_stylebox_override("fill", UI.style(Color(0.9, 0.3, 0.2), 8, Color(0, 0, 0, 0), 0, 0))
	boss_box.add_child(boss_name)
	boss_box.add_child(boss_bar)
	boss_box.visible = false
	root.add_child(boss_box)

	toast_box = VBoxContainer.new()
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.custom_minimum_size = Vector2(520, 0)
	root.add_child(toast_box)

	# touch buttons
	btn_jump = _tbtn("jump", "Jump", 56)
	btn_act = _tbtn("act", "Act", 54)
	btn_strike = _tbtn("strike", "Strike", 44)
	btn_ability = _tbtn("paw", "", 44)
	btn_build = _tbtn("build", "Build", 36)
	btn_pause = _tbtn("pause", "", 30)
	btn_map = _tbtn("map", "", 30)
	btn_pack = _tbtn("bag", "", 30)
	btn_journal = _tbtn("book", "", 30)
	btn_place = _tbtn("check", "Place", 54)
	btn_rotate = _tbtn("rotate", "Rotate", 44)
	btn_cancel = _tbtn("close", "Cancel", 44)
	btn_hint = _tbtn("close", "", 20)
	btn_strike.tint = Color(0.9, 0.3, 0.25)
	btn_place.tint = Color(0.3, 0.8, 0.4)
	btn_cancel.tint = Color(0.85, 0.3, 0.3)
	btn_jump.tint = Color(0.3, 0.7, 0.9)
	btn_hint.tint = Color(0.4, 0.4, 0.45)
	for b in [btn_pause, btn_map, btn_pack, btn_journal]:
		b.tint = Color(0.25, 0.4, 0.5)
	btn_jump.pressed.connect(player.request_jump)
	btn_jump.released.connect(player.release_jump)
	btn_act.pressed.connect(func(): player.do_primary())
	btn_strike.pressed.connect(func(): player.do_strike())
	btn_ability.pressed.connect(func(): player.use_ability())
	btn_build.pressed.connect(func(): build_menu.open())
	btn_pause.pressed.connect(open_pause)
	btn_map.pressed.connect(open_map)
	btn_pack.pressed.connect(open_inventory)
	btn_journal.pressed.connect(open_journal)
	btn_place.pressed.connect(func(): world.build_manager.confirm())
	btn_rotate.pressed.connect(func(): world.build_manager.rotate_preview())
	btn_cancel.pressed.connect(func(): world.build_manager.cancel())
	btn_hint.pressed.connect(_dismiss_hint)

	# panels (added last so they draw above the HUD)
	inventory_panel = InventoryPanel.new()
	journal_panel = JournalPanel.new()
	map_panel = MapPanel.new()
	pause_menu = PauseMenu.new()
	settings_panel = SettingsPanel.new(true)
	lore_panel = Panels.LorePanel.new()
	chest_panel = Panels.ChestPanel.new()
	plot_panel = Panels.PlotPanel.new()
	rest_panel = Panels.RestPanel.new()
	build_menu = Panels.BuildMenu.new()
	confirm = Panels.ConfirmDialog.new()
	for p in [inventory_panel, journal_panel, map_panel, pause_menu, settings_panel, lore_panel, chest_panel, plot_panel, rest_panel, build_menu, confirm]:
		root.add_child(p)
	for p in [inventory_panel, journal_panel, map_panel, build_menu]:
		p.world = world
	pause_menu.hud = self
	journal_panel.confirm = confirm
	build_menu.world = world
	_build_defeat_overlay()

	root.resized.connect(_layout)
	_layout()
	Game.notify.connect(_on_notify)
	Game.leveled_up.connect(_on_level_up)
	Game.state_changed.connect(_on_state)
	Game.stats_changed.connect(func(): bars.queue_redraw())
	Game.xp_changed.connect(func(): bars.queue_redraw())
	Quests.quest_updated.connect(_update_quest_text)
	Quests.quest_completed.connect(func(_id): if player.is_alive() and Game.is_playing(): player.celebrate())
	_update_quest_text()
	_on_state(Game.state)


func _tbtn(glyph: String, label: String, r: float) -> Control:
	var b := TouchButton.new(glyph, label, r)
	root.add_child(b)
	touch.register(b)
	return b


func _place(b: Control, center: Vector2) -> void:
	b.position = center - b.size * 0.5


func _layout() -> void:
	var vs := root.get_viewport_rect().size
	var m := UI.safe_margins(root.get_viewport())
	var mr: float = m["r"] + 18.0
	var mb: float = m["b"] + 18.0
	var ml: float = m["l"] + 18.0
	var mt: float = m["t"] + 10.0
	_place(btn_jump, Vector2(vs.x - mr - 66, vs.y - mb - 66))
	_place(btn_act, Vector2(vs.x - mr - 210, vs.y - mb - 54))
	_place(btn_strike, Vector2(vs.x - mr - 62, vs.y - mb - 215))
	_place(btn_ability, Vector2(vs.x - mr - 205, vs.y - mb - 175))
	_place(btn_build, Vector2(vs.x - mr - 350, vs.y - mb - 44))
	_place(btn_place, Vector2(vs.x - mr - 210, vs.y - mb - 54))
	_place(btn_rotate, Vector2(vs.x - mr - 62, vs.y - mb - 215))
	_place(btn_cancel, Vector2(vs.x - mr - 205, vs.y - mb - 175))
	for i in 4:
		var b: Control = [btn_pause, btn_map, btn_pack, btn_journal][i]
		_place(b, Vector2(vs.x - mr - 34 - i * 74, mt + 38))
	bars.position = Vector2(ml, mt)
	comp_label.position = Vector2(ml, mt + 132)
	compass.size = Vector2(380, 44)
	compass.position = Vector2((vs.x - 380) * 0.5, mt)
	quest_box.position = Vector2((vs.x - 420) * 0.5, mt + 52)
	hint_box.position = Vector2((vs.x - 420) * 0.5, mt + 150)
	prompt_label.position = Vector2(vs.x - mr - 420 - 130, vs.y - mb - 160 - 0)
	build_label.position = Vector2((vs.x - 600) * 0.5, mt + 56)
	boss_box.position = Vector2((vs.x - 420) * 0.5, mt + 150)
	toast_box.position = Vector2(vs.x * 0.5 - 260, vs.y * 0.5 - 40)
	touch.joy_rest = Vector2(ml + 150, vs.y - mb - 130)
	touch.queue_redraw()
	_place(btn_hint, hint_box.position + Vector2(404, -4))


# ------------------------------------------------------------ per-frame
func _process(delta: float) -> void:
	if player == null:
		return
	_t -= delta
	var yaw: float = player.cam_yaw
	if absf(yaw - _last_yaw) > 0.002:
		_last_yaw = yaw
		compass.queue_redraw()
	if _t > 0.0:
		return
	_t = 0.1
	var building: bool = Game.state == Game.State.BUILDING and world.build_manager.active
	var playing: bool = Game.state == Game.State.PLAY
	var boss: Node = world.engaged_boss()
	var has_comp := not Game.active_creature().is_empty()
	var has_kit := false
	var kits := 0
	for s in Inv.slots:
		if s != null and Data.get_item(s["id"])["kind"] == "building":
			has_kit = true
			kits += int(s["n"])
	btn_act.visible = playing and player.prompt != ""
	btn_act.set_label("Act")
	prompt_label.text = player.prompt if playing else ""
	btn_strike.visible = playing and (boss != null or world.nearest_hostile(player.global_position, 12.0) != null)
	btn_ability.visible = playing and has_comp
	btn_build.visible = playing and has_kit
	btn_build.badge = str(kits) if kits > 0 else ""
	btn_place.visible = building
	btn_rotate.visible = building
	btn_cancel.visible = building
	btn_jump.visible = playing or building
	for b in [btn_pause, btn_map, btn_pack, btn_journal]:
		b.visible = playing or building
	if has_comp:
		btn_ability.set_label(player.ability_name())
		btn_ability.cooldown_frac = clampf(player.ability_cd / maxf(player.ability_cd_max, 0.1), 0.0, 1.0)
		var c := Game.active_creature()
		comp_label.text = "Companion: %s  Lv %d" % [c["name"], int(c["level"])]
	else:
		comp_label.text = "No companion"
	build_label.text = world.build_manager.status_text() if building else ""
	build_label.add_theme_color_override("font_color", UI.COL_GOOD if (building and world.build_manager.last_result.get("ok", false)) else UI.COL_BAD)
	if boss != null:
		boss_box.visible = true
		boss_name.text = "%s%s" % [boss.def["name"], "  (Enraged)" if boss.phase == 2 else ""]
		boss_bar.max_value = boss.max_hp
		boss_bar.value = maxf(boss.hp, 0.0)
	else:
		boss_box.visible = false
	_update_hint()
	if Game.state == Game.State.PLAY:
		quest_label.visible = true
	compass.queue_redraw()


func _update_quest_text() -> void:
	var id := Quests.tracked()
	if id == "":
		quest_label.text = "All current quests complete. Explore Aetherwild!"
		return
	var q: Dictionary = Data.quests[id]
	var lines: Array = [q["name"]]
	for i in q["objectives"].size():
		lines.append("- " + Quests.objective_text(id, i))
	quest_label.text = "\n".join(lines)
	_update_hint()


func _update_hint() -> void:
	var id := Quests.tracked()
	var show_hint: bool = id != "" and Data.quests[id]["hint"] != "" and not Game.dismissed_hints.has(id) and Game.state == Game.State.PLAY and not boss_box.visible
	hint_box.visible = show_hint
	btn_hint.visible = show_hint
	if show_hint:
		hint_label.text = Data.quests[id]["hint"]


func _dismiss_hint() -> void:
	var id := Quests.tracked()
	if id != "":
		Game.dismissed_hints[id] = true
	_update_hint()


# ------------------------------------------------------------ notifications
func _on_notify(text: String, kind: String) -> void:
	if toast_box.get_child_count() >= 4:
		toast_box.get_child(0).queue_free()
	var pc := PanelContainer.new()
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := Color(0.1, 0.18, 0.22, 0.92)
	var border := UI.COL_ACCENT2
	match kind:
		"warn": border = UI.COL_BAD
		"quest": border = UI.COL_ACCENT
		"discover": border = Color(0.5, 0.75, 1.0)
		"level": border = Color(1.0, 0.85, 0.3)
	pc.add_theme_stylebox_override("panel", UI.style(col, 14, border, 2, 12))
	var l := UI.label(text, 21, UI.COL_TEXT, true)
	l.custom_minimum_size.x = 460
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pc.add_child(l)
	toast_box.add_child(pc)
	var tw := pc.create_tween()
	tw.tween_interval(3.2)
	tw.tween_property(pc, "modulate:a", 0.0, 0.6)
	tw.tween_callback(pc.queue_free)
	if kind == "warn":
		Sfx.play("warn")


func _on_level_up(level: int, unlocks: Array) -> void:
	Game.toast("Level %d reached!" % level, "level")
	for u in unlocks:
		Game.toast("Unlocked - " + u, "level")
	Sfx.play("levelup")
	if world and player:
		world.spawn_burst(player.global_position + Vector3(0, 1.5, 0), Color(1.0, 0.9, 0.3), 24)
	Quests.refresh_unlocks(true)


func _on_state(s: int) -> void:
	touch.active = (s == Game.State.PLAY or s == Game.State.BUILDING)
	defeat_overlay.visible = (s == Game.State.DEFEAT)
	root.visible = true
	touch.queue_redraw()


# ------------------------------------------------------------ opening panels
func _free_to_open() -> bool:
	return Game.state == Game.State.PLAY or Game.state == Game.State.BUILDING


func open_inventory() -> void:
	if _free_to_open():
		inventory_panel.open_tab("pack")


func open_crafting(station: String) -> void:
	if _free_to_open():
		inventory_panel.open_tab("craft", station)


func open_journal() -> void:
	if _free_to_open() or Game.state == Game.State.PAUSE:
		journal_panel.open_tab("wildlings")


func open_map() -> void:
	if _free_to_open():
		map_panel.open()


func open_pause() -> void:
	if _free_to_open():
		pause_menu.open()


func open_chest(s: Node) -> void:
	if _free_to_open():
		chest_panel.open_for(s)


func open_plot(s: Node) -> void:
	if _free_to_open():
		plot_panel.open_for(s)


func open_rest(s: Node) -> void:
	if _free_to_open():
		rest_panel.open_for(s)


func open_lore(key: String) -> void:
	if _free_to_open():
		lore_panel.show_lore(key)


## Android back button / Escape.
func handle_back() -> void:
	for p in [confirm, settings_panel, lore_panel, chest_panel, plot_panel, rest_panel, build_menu, journal_panel, inventory_panel, map_panel, pause_menu]:
		if p.is_open:
			p.close()
			return
	if Game.state == Game.State.BUILDING:
		world.build_manager.cancel()
	elif Game.state == Game.State.PLAY:
		open_pause()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			handle_back()
		elif event.keycode == KEY_I:
			open_inventory()
		elif event.keycode == KEY_M:
			open_map()
		elif event.keycode == KEY_J:
			open_journal()
		elif event.keycode == KEY_B and btn_build.visible:
			build_menu.open()


func _input(event: InputEvent) -> void:
	# keyboard shortcuts for desktop testing (touch buttons handle phones)
	if event is InputEventKey and event.pressed and not event.echo and Game.state == Game.State.PLAY:
		if event.is_action("jump"):
			player.request_jump()
		elif event.is_action("act"):
			player.do_primary()
		elif event.is_action("strike"):
			player.do_strike()
		elif event.is_action("ability"):
			player.use_ability()
	elif event is InputEventKey and not event.pressed and event.is_action("jump"):
		player.release_jump()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			player.apply_zoom(-0.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			player.apply_zoom(0.5)


func return_to_menu() -> void:
	if world:
		world.save_now(true)
	for p in [confirm, settings_panel, lore_panel, chest_panel, plot_panel, rest_panel, build_menu, journal_panel, inventory_panel, map_panel, pause_menu]:
		p.force_close()
	Game.clear_state_stack()
	Game.set_state(Game.State.MENU)
	Sfx.play_ambience(false)
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


# ------------------------------------------------------------ defeat overlay
func _build_defeat_overlay() -> void:
	defeat_overlay = Control.new()
	defeat_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	defeat_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	defeat_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	defeat_overlay.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.25, 0.02, 0.02, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	defeat_overlay.add_child(dim)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	defeat_overlay.add_child(c)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(520, 0)
	c.add_child(v)
	var t := UI.label("You collapsed", 48, Color(1, 0.8, 0.7))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := UI.label("Your items, Wildlings and progress are safe. Rest at camp and try again.", 22, UI.COL_TEXT, true)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	v.add_child(UI.spacer(14))
	v.add_child(UI.button("Recover at camp", func(): world.recover_player(), Vector2(0, 68), true))
	root.add_child(defeat_overlay)


# ------------------------------------------------------------ custom-drawn widgets
class StatBars extends Control:
	const W := 230.0
	const H := 18.0

	func _init() -> void:
		custom_minimum_size = Vector2(320, 130)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var items := [
			["health", Game.health / Game.max_health, Color(0.9, 0.25, 0.3), "HP %d" % int(Game.health)],
			["stamina", Game.stamina / 100.0, Color(0.95, 0.85, 0.25), "STA"],
			["hunger", Game.hunger / 100.0, Color(0.95, 0.55, 0.2), "FOOD"],
			["comfort", Game.comfort / 100.0, Color(0.4, 0.85, 0.5), "TEMP"],
		]
		var kind: String = str(Game.get_meta("comfort_kind", "ok"))
		var font := ThemeDB.fallback_font
		var t := Time.get_ticks_msec() * 0.008
		for i in items.size():
			var y := i * 28.0
			var frac: float = clampf(items[i][1], 0.0, 1.0)
			var col: Color = items[i][2]
			var label: String = items[i][3]
			if items[i][0] == "comfort":
				if Game.comfort < 40.0:
					col = Color(0.95, 0.5, 0.2) if kind == "hot" else Color(0.45, 0.7, 1.0)
					label = "HOT" if kind == "hot" else "COLD"
			var low := frac < 0.25
			_icon(items[i][0], Vector2(14, y + 11), col)
			draw_rect(Rect2(34, y, W, H), Color(0, 0, 0, 0.55))
			draw_rect(Rect2(34, y, W * frac, H), col)
			var border := Color(1, 1, 1, 0.6)
			if low and int(t) % 2 == 0:
				border = Color(1, 0.2, 0.2, 1.0)
			draw_rect(Rect2(34, y, W, H), border, false, 2.0)
			var txt := label + (" !" if low else "")
			draw_string_outline(font, Vector2(40, y + 14), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 5, Color(0, 0, 0, 0.9))
			draw_string(font, Vector2(40, y + 14), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
		# level + xp
		var xp_frac := float(Game.xp) / float(Game.xp_needed())
		draw_rect(Rect2(34, 114, W, 8), Color(0, 0, 0, 0.55))
		draw_rect(Rect2(34, 114, W * xp_frac, 8), Color(0.5, 0.75, 1.0))
		draw_string_outline(font, Vector2(2, 124), "Lv %d" % Game.level, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 5, Color.BLACK)
		draw_string(font, Vector2(2, 124), "Lv %d" % Game.level, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

	func _icon(kind: String, c: Vector2, col: Color) -> void:
		match kind:
			"health":
				draw_circle(c + Vector2(-4, -3), 5, col)
				draw_circle(c + Vector2(4, -3), 5, col)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-9, -1), c + Vector2(9, -1), c + Vector2(0, 9)]), col)
			"stamina":
				draw_colored_polygon(PackedVector2Array([c + Vector2(2, -10), c + Vector2(-6, 2), c + Vector2(0, 2), c + Vector2(-2, 10), c + Vector2(7, -3), c + Vector2(1, -3)]), col)
			"hunger":
				draw_circle(c + Vector2(0, 2), 7, col)
				draw_line(c + Vector2(0, -4), c + Vector2(3, -9), Color(0.4, 0.8, 0.4), 3.0)
			"comfort":
				draw_rect(Rect2(c.x - 2.5, c.y - 10, 5, 14), col)
				draw_circle(c + Vector2(0, 6), 5, col)


class Compass extends Control:
	var hud: Node = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if hud == null or hud.player == null:
			return
		var w := size.x
		var h := size.y
		draw_rect(Rect2(0, 0, w, h), Color(0.03, 0.06, 0.08, 0.55))
		draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, 0.35), false, 2.0)
		var bearing := -float(hud.player.cam_yaw)
		var span := deg_to_rad(140.0)
		var font := ThemeDB.fallback_font
		var marks := {"N": 0.0, "E": PI * 0.5, "S": PI, "W": -PI * 0.5}
		for k in marks:
			var rel := wrapf(float(marks[k]) - bearing, -PI, PI)
			if absf(rel) < span * 0.5:
				var x := w * 0.5 + rel / span * w
				var col := Color(1, 0.5, 0.4) if k == "N" else Color.WHITE
				draw_string(font, Vector2(x - 7, 30), k, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, col)
		draw_line(Vector2(w * 0.5, 0), Vector2(w * 0.5, 7), Color(1, 0.85, 0.3), 3.0)
		# tracked quest marker (real world location)
		var id := Quests.tracked()
		if id != "" and hud.world != null:
			var mp: Variant = hud.world.marker_pos(Data.quests[id]["marker"])
			if mp != null:
				var d: Vector3 = mp - hud.player.global_position
				var mb := atan2(d.x, -d.z)
				var rel2 := wrapf(mb - bearing, -PI, PI)
				var x2 := clampf(w * 0.5 + rel2 / span * w, 12.0, w - 12.0)
				var edge := absf(rel2) >= span * 0.5
				draw_colored_polygon(PackedVector2Array([Vector2(x2, 8), Vector2(x2 + 9, 20), Vector2(x2, 32), Vector2(x2 - 9, 20)]), Color(1.0, 0.8, 0.2, 0.6 if edge else 1.0))
				var dist := "%dm" % int(Vector2(d.x, d.z).length())
				draw_string(font, Vector2(x2 - 14, h + 14), dist, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 0.9, 0.5))
