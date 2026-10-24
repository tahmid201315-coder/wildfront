extends Control
## Main menu with a lightweight animated background (a handful of 2D draw calls).

const UI = preload("res://scripts/ui/ui_kit.gd")
const SettingsPanel = preload("res://scripts/ui/settings_panel.gd")
const Panels = preload("res://scripts/ui/station_panels.gd")
const Modal = preload("res://scripts/ui/modal.gd")

var _t: float = 0.0
var _wisps: Array = []
var _stars: Array = []
var _menu: VBoxContainer
var _msg: Label
var _continue: Button
var _settings: Control
var _credits: Control
var _confirm: Control
var _loading: bool = false


func _ready() -> void:
	theme = UI.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Game.state = Game.State.MENU
	get_tree().paused = false
	Game.world = null
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 28:
		_wisps.append([rng.randf(), rng.randf(), rng.randf_range(0.02, 0.06), rng.randf_range(2.0, 6.0), rng.randf() * TAU])
	for i in 60:
		_stars.append([rng.randf(), rng.randf() * 0.5, rng.randf_range(1.0, 2.5), rng.randf() * TAU])
	_build_ui()
	Sfx.play_music("menu")
	Sfx.play_ambience(false)
	if Game.menu_message != "":
		_msg.text = Game.menu_message
		Game.menu_message = ""
	resized.connect(_layout)
	_layout()


func _build_ui() -> void:
	_menu = VBoxContainer.new()
	_menu.custom_minimum_size = Vector2(380, 0)
	add_child(_menu)
	_continue = UI.button("Continue", _on_continue, Vector2(0, 66), true)
	_menu.add_child(_continue)
	_menu.add_child(UI.button("New Game", _on_new_game, Vector2(0, 62)))
	_menu.add_child(UI.button("Settings", func(): _settings.open(), Vector2(0, 58)))
	_menu.add_child(UI.button("Credits", func(): _credits.open(), Vector2(0, 58)))
	_menu.add_child(UI.button("Exit", func(): get_tree().quit(), Vector2(0, 58)))
	_msg = UI.label("", 20, Color(1.0, 0.75, 0.5), true)
	_msg.custom_minimum_size = Vector2(380, 0)
	_menu.add_child(_msg)
	_continue.disabled = not Save.has_save()
	_settings = SettingsPanel.new(false)
	add_child(_settings)
	_credits = _make_credits()
	add_child(_credits)
	_confirm = Panels.ConfirmDialog.new()
	add_child(_confirm)


func _make_credits() -> Control:
	var m: Control = Modal.new("Credits", Game.State.PAUSE, false)
	m.max_size = Vector2(820, 560)
	m.ready.connect(func():
		var sc := ScrollContainer.new()
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var l := UI.label("WILDFRONT: CREATURE SURVIVAL  v%s\n\nBuilt with Godot Engine 4.3 (MIT licence).\n\nAll Wildlings, characters, terrain, interface art, music and sound effects in this build are original and generated in code at runtime. There are no third-party art or audio assets in this build. Any future assets will be listed in docs/ASSETS.md with their licences.\n\nThe world of Aetherwild, the Wildcores, and every creature name are original creations and are not affiliated with any other game." % Data.GAME_VERSION, 22, UI.COL_TEXT, true)
		l.custom_minimum_size.x = 700
		sc.add_child(l)
		m.body.add_child(sc))
	return m


func _layout() -> void:
	var m := UI.safe_margins(get_viewport())
	_menu.position = Vector2(size.x - 420 - m["r"], maxf(size.y * 0.5 - 190, 20.0))


func _on_continue() -> void:
	if _loading:
		return
	var res: Dictionary = Save.load_game()
	if not res["ok"]:
		_msg.text = str(res["message"])
		_continue.disabled = true
		Sfx.play("invalid")
		return
	if res["restored_backup"]:
		_msg.text = str(res["message"])
	_start_game(true)


func _on_new_game() -> void:
	if _loading:
		return
	if Save.has_save():
		_confirm.ask("Start a new game?", "This will replace your existing saved progress. This cannot be undone.", func():
			Save.delete_save()
			_start_game(false), "Replace my save")
	else:
		_start_game(false)


func _start_game(continue_game: bool) -> void:
	_loading = true
	_menu.visible = false
	_msg.text = ""
	if not continue_game:
		Game.reset_progress()
		Inv.clear()
		Quests.reset()
	Game.pending_continue = continue_game
	Game.set_state(Game.State.LOADING)
	get_tree().paused = false
	queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	var err := get_tree().change_scene_to_file("res://scenes/world/world.tscn")
	if err != OK:
		_loading = false
		_menu.visible = true
		Game.set_state(Game.State.MENU)
		_msg.text = "Could not load the world (error %d)." % err


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var s := size
	var steps := 24
	for i in steps:
		var f := float(i) / steps
		var col := Color(0.09, 0.14, 0.32).lerp(Color(0.95, 0.55, 0.35), pow(f, 2.2))
		draw_rect(Rect2(0, f * s.y * 0.75, s.x, s.y * 0.75 / steps + 1), col)
	for st in _stars:
		var a: float = 0.4 + 0.6 * (0.5 + 0.5 * sin(_t * 1.5 + float(st[3])))
		draw_circle(Vector2(st[0] * s.x, st[1] * s.y), st[2], Color(1, 1, 1, a * 0.7))
	draw_circle(Vector2(s.x * 0.22, s.y * 0.58), 70.0, Color(1.0, 0.85, 0.5, 0.9))
	draw_circle(Vector2(s.x * 0.22, s.y * 0.58), 105.0, Color(1.0, 0.7, 0.4, 0.15))
	var layers := [[0.62, Color(0.28, 0.2, 0.35), 0.006, 38.0], [0.72, Color(0.15, 0.3, 0.3), 0.009, 52.0], [0.84, Color(0.08, 0.2, 0.2), 0.012, 64.0]]
	for li in layers.size():
		var L: Array = layers[li]
		var pts := PackedVector2Array()
		for x in range(0, int(s.x) + 40, 40):
			var y: float = s.y * float(L[0]) + sin(x * float(L[2]) + _t * 0.1 * (li + 1)) * float(L[3]) + sin(x * float(L[2]) * 2.3) * float(L[3]) * 0.4
			pts.append(Vector2(x, y))
		pts.append(Vector2(s.x + 40, s.y))
		pts.append(Vector2(0, s.y))
		draw_colored_polygon(pts, L[1])
	for w in _wisps:
		var x: float = fposmod(float(w[0]) + _t * float(w[2]) * 0.2, 1.0) * s.x
		var y: float = s.y * (0.35 + float(w[1]) * 0.5) + sin(_t * 0.8 + float(w[4])) * 14.0
		var a: float = 0.35 + 0.35 * sin(_t * 1.7 + float(w[4]))
		draw_circle(Vector2(x, y), w[3], Color(1.0, 0.95, 0.6, a * 0.35))
		draw_circle(Vector2(x, y), w[3] * 0.4, Color(1.0, 1.0, 0.8, a))
	var sc := clampf(s.y / 720.0, 0.6, 1.3)
	var lc := Vector2(s.x * 0.3, s.y * 0.36)
	UI.draw_logo(self, lc, sc, _t)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(12, s.y - 10), "v" + Data.GAME_VERSION + "  |  Offline single-player", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.55))
	if _loading:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.05, 0.08, 0.1, 0.92))
		var txt := "Loading Aetherwild..."
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 36).x
		draw_string(font, Vector2((s.x - tw) * 0.5, s.y * 0.55), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color.WHITE)
		var a2 := _t * 4.0
		for i in 8:
			var ang := a2 + i * TAU / 8.0
			draw_circle(Vector2(s.x * 0.5, s.y * 0.65) + Vector2(cos(ang), sin(ang)) * 26.0, 5.0, Color(1, 0.8, 0.3, 0.2 + 0.1 * i))
