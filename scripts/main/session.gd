extends Node
## One play session: owns the world, HUD and panels. Created by Main when a game starts.

signal quit_to_menu

const UI = preload("res://scripts/ui/ui_kit.gd")
const World = preload("res://scripts/world/world.gd")
const Hud = preload("res://scripts/ui/hud.gd")
const SettingsPanel = preload("res://scripts/ui/settings_panel.gd")
const ConfirmDialog = preload("res://scripts/ui/confirm_dialog.gd")
const Modal = preload("res://scripts/ui/modal.gd")
const InventoryPanel = preload("res://scripts/ui/inventory_panel.gd")
const CraftPanel = preload("res://scripts/ui/craft_panel.gd")
const StoragePanel = preload("res://scripts/ui/storage_panel.gd")

var world: Node3D
var hud: Control
var ui_layer: CanvasLayer
var loading: Control
var panels: Dictionary = {}
var pause_menu: Control
var settings: Control
var confirm: Control
var continue_game: bool = false
var _load_f: float = 0.0
var _load_text: String = ""
var _autosave_t: float = 0.0


func start(cont: bool) -> void:
	continue_game = cont
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.set_state(Game.State.LOADING)
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	loading = _make_loading()
	ui_layer.add_child(loading)
	var saved: Dictionary = {}
	if cont:
		var r: Dictionary = Save.load_game()
		if r["ok"]:
			saved = r["data"]
		else:
			continue_game = false
	if continue_game:
		Game.deserialize(saved["game"])
		Inv.deserialize(saved["inventory"])
		Quests.deserialize(saved["quests"])
	else:
		Game.reset_progress()
		Inv.clear()
		Quests.reset()
		_starting_kit()
	world = World.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	world.loading_progress.connect(func(f, t):
		_load_f = f
		_load_text = t)
	world.build(continue_game)
	await world.loaded
	if continue_game:
		world.apply_world(saved.get("world", {}))
	_setup_ui()
	hud.bind(world, world.player)
	world.hud = hud
	world.player.died.connect(_on_player_died)
	Quests.refresh(false)
	Game.set_state(Game.State.PLAY)
	loading.queue_free()
	loading = null
	Sfx.stop_music()
	if not continue_game:
		hud.banner("CRASH LANDING", "Find supplies. Make a tool. Survive.")
		Game.set_flag("intro_done", true)
	else:
		Game.toast("Game loaded.", "info")


func _starting_kit() -> void:
	Inv.add("bandage", 2)
	Inv.add("berries", 4)


func _make_loading() -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.theme = UI.theme()
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	var t := [0.0]
	c.draw.connect(func():
		var s := c.size
		c.draw_rect(Rect2(Vector2.ZERO, s), Color(0.04, 0.07, 0.08))
		var sc := clampf(s.y / 720.0, 0.6, 1.4)
		UI.draw_logo(c, Vector2(s.x * 0.5, s.y * 0.36), sc, t[0])
		var bw := 460.0 * sc
		var bx := (s.x - bw) * 0.5
		var by := s.y * 0.78
		c.draw_rect(Rect2(bx, by, bw, 14), Color(0, 0, 0, 0.5))
		c.draw_rect(Rect2(bx, by, bw * _load_f, 14), UI.COL_ACCENT)
		c.draw_rect(Rect2(bx, by, bw, 14), Color(1, 1, 1, 0.5), false, 2.0)
		var font := ThemeDB.fallback_font
		var tw := font.get_string_size(_load_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 22).x
		c.draw_string(font, Vector2((s.x - tw) * 0.5, by + 42), _load_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.8, 0.9, 0.9)))
	c.process_mode = Node.PROCESS_MODE_ALWAYS
	var timer := Timer.new()
	timer.wait_time = 0.05
	timer.autostart = true
	timer.timeout.connect(func():
		t[0] += 0.05
		c.queue_redraw())
	c.add_child(timer)
	return c


func _setup_ui() -> void:
	hud = Hud.new()
	ui_layer.add_child(hud)
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.panel_requested.connect(open_panel)
	settings = SettingsPanel.new(true)
	ui_layer.add_child(settings)
	confirm = ConfirmDialog.new()
	ui_layer.add_child(confirm)
	for pair in [["inventory", InventoryPanel], ["craft", CraftPanel]]:
		var pn: Control = pair[1].new()
		ui_layer.add_child(pn)
		panels[pair[0]] = pn
	var sp: Control = StoragePanel.new()
	ui_layer.add_child(sp)
	hud.storage_requested.connect(func(b): sp.show_for(b))
	pause_menu = _make_pause()
	ui_layer.add_child(pause_menu)
	Game.state_changed.connect(_on_state)


func open_panel(name: String) -> void:
	if Game.state != Game.State.PLAY:
		return
	if name == "pause":
		pause_menu.open()
	elif panels.has(name):
		panels[name].open()
	else:
		Game.toast("Not available yet.", "warn")


func _on_state(_s: int) -> void:
	if hud:
		hud.touch.active = Game.is_playing()
		hud.visible = Game.state != Game.State.ENDING


func _make_pause() -> Control:
	var m: Control = Modal.new("Paused", Game.State.PAUSE, true)
	m.max_size = Vector2(560, 560)
	m.ready.connect(func():
		var col := VBoxContainer.new()
		col.size_flags_vertical = Control.SIZE_EXPAND_FILL
		m.body.add_child(col)
		col.add_child(UI.button("Resume", func(): m.close(), Vector2(0, 62), true))
		col.add_child(UI.button("Save Game", func():
			world.save_now(false), Vector2(0, 58)))
		col.add_child(UI.button("Settings", func(): settings.open(), Vector2(0, 58)))
		col.add_child(UI.button("Save and Quit to Menu", func():
			m.close()
			world.save_now(false)
			quit_to_menu.emit(), Vector2(0, 58)))
		col.add_child(UI.button("Quit without Saving", func():
			confirm.ask("Quit without saving?", "Progress since your last save will be lost.", func():
				m.close()
				quit_to_menu.emit(), "Quit"), Vector2(0, 58))))
	return m


func _unhandled_input(event: InputEvent) -> void:
	if hud == null:
		return
	if event.is_action_pressed("ui_cancel"):
		if Game.state == Game.State.PLAY:
			pause_menu.open()
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and hud != null and Game.state == Game.State.PLAY:
		pause_menu.open()


func _on_player_died() -> void:
	pass


func _process(delta: float) -> void:
	if world == null or hud == null:
		return
	if Game.state == Game.State.PLAY:
		_autosave_t += delta
		if _autosave_t > 90.0:
			_autosave_t = 0.0
			world.save_now(true)
