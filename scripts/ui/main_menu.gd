extends Control
## Main menu: Continue / New Game (with overwrite confirmation) / Settings / Credits / Exit.

signal start_game(continue_game: bool)

const UI = preload("res://scripts/ui/ui_kit.gd")
const SettingsPanel = preload("res://scripts/ui/settings_panel.gd")
const ConfirmDialog = preload("res://scripts/ui/confirm_dialog.gd")
const Modal = preload("res://scripts/ui/modal.gd")

var _t: float = 0.0
var _stars: Array = []
var _menu: VBoxContainer
var _msg: Label
var _continue: Button
var _settings: Control
var _credits: Control
var _confirm: Control


func _ready() -> void:
	theme = UI.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Game.state = Game.State.MENU
	get_tree().paused = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 70:
		_stars.append([rng.randf(), rng.randf() * 0.55, rng.randf_range(0.8, 2.2), rng.randf() * TAU])
	_build_ui()
	Sfx.play_music("menu")
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
	_confirm = ConfirmDialog.new()
	add_child(_confirm)


func _make_credits() -> Control:
	var m: Control = Modal.new("Credits", Game.State.PAUSE, false)
	m.max_size = Vector2(820, 560)
	m.ready.connect(func():
		var sc := ScrollContainer.new()
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var l := UI.label("PROJECT WILDLANDS  v%s\n\nBuilt with Godot Engine 4.3 (MIT licence).\n\nEvery model, texture, interface icon, music track and sound effect in this build is original and generated in code at runtime. There are no third-party art or audio assets. See docs/ASSETS.md.\n\nThe island, its regions, the Helix Consortium, the Core Architect and every creature are original creations." % Data.GAME_VERSION, 22, UI.COL_TEXT, true)
		l.custom_minimum_size.x = 700
		sc.add_child(l)
		m.body.add_child(sc))
	return m


func _layout() -> void:
	var m := UI.safe_margins(get_viewport())
	_menu.position = Vector2(size.x - 420 - m["r"], maxf(size.y * 0.5 - 190, 20.0))


func _on_continue() -> void:
	var res: Dictionary = Save.load_game()
	if not res["ok"]:
		_msg.text = str(res["message"])
		_continue.disabled = true
		Sfx.play("invalid")
		return
	if res["restored_backup"]:
		Game.menu_message = str(res["message"])
	start_game.emit(true)


func _on_new_game() -> void:
	if Save.has_save():
		_confirm.ask("Start a new game?", "This replaces your existing saved progress and cannot be undone.", func():
			Save.delete_save()
			start_game.emit(false), "Replace my save")
	else:
		start_game.emit(false)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var s := size
	var steps := 28
	for i in steps:
		var f := float(i) / steps
		var col := Color(0.05, 0.10, 0.22).lerp(Color(0.95, 0.60, 0.38), pow(f, 2.4))
		draw_rect(Rect2(0, f * s.y * 0.8, s.x, s.y * 0.8 / steps + 1), col)
	for st in _stars:
		var a: float = 0.4 + 0.6 * (0.5 + 0.5 * sin(_t * 1.5 + float(st[3])))
		draw_circle(Vector2(st[0] * s.x, st[1] * s.y), st[2], Color(1, 1, 1, a * 0.7))
	draw_circle(Vector2(s.x * 0.2, s.y * 0.6), 66.0, Color(1.0, 0.9, 0.6, 0.95))
	draw_circle(Vector2(s.x * 0.2, s.y * 0.6), 110.0, Color(1.0, 0.75, 0.45, 0.14))
	var layers := [[0.62, Color(0.30, 0.22, 0.38), 0.006, 40.0], [0.74, Color(0.14, 0.30, 0.30), 0.009, 52.0], [0.86, Color(0.06, 0.18, 0.17), 0.012, 60.0]]
	for li in layers.size():
		var L: Array = layers[li]
		var pts := PackedVector2Array()
		for x in range(0, int(s.x) + 40, 40):
			var y: float = s.y * float(L[0]) + sin(x * float(L[2]) + _t * 0.05 * (li + 1)) * float(L[3]) + sin(x * float(L[2]) * 2.3) * float(L[3]) * 0.4
			pts.append(Vector2(x, y))
		pts.append(Vector2(s.x + 40, s.y))
		pts.append(Vector2(0, s.y))
		draw_colored_polygon(pts, L[1])
	var sc := clampf(s.y / 720.0, 0.6, 1.3)
	UI.draw_logo(self, Vector2(s.x * 0.3, s.y * 0.36), sc, _t)
	draw_string(ThemeDB.fallback_font, Vector2(12, s.y - 10), "v" + Data.GAME_VERSION + "  |  Offline single-player", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.55))
