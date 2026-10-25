extends Control
## Root: boot -> main menu -> session (loading, world, HUD) -> back to menu.

const UI = preload("res://scripts/ui/ui_kit.gd")
const Boot = preload("res://scripts/main/boot.gd")
const MainMenu = preload("res://scripts/ui/main_menu.gd")
const Session = preload("res://scripts/main/session.gd")

var _current: Node = null
var _session: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UI.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var boot := Boot.new()
	_swap(boot)
	boot.finished.connect(_show_menu)


func _swap(n: Node) -> void:
	if _current and is_instance_valid(_current):
		_current.queue_free()
	_current = n
	add_child(n)


func _show_menu() -> void:
	Game.set_state(Game.State.MENU)
	get_tree().paused = false
	var menu := MainMenu.new()
	_swap(menu)
	menu.start_game.connect(_start_session)


func _start_session(cont: bool) -> void:
	if _current and is_instance_valid(_current):
		_current.queue_free()
		_current = null
	_session = Session.new()
	add_child(_session)
	_session.quit_to_menu.connect(_end_session)
	_session.start(cont)


func _end_session() -> void:
	if _session:
		_session.queue_free()
		_session = null
	Game.world = null
	Game.clear_state_stack()
	get_tree().paused = false
	Game.set_state(Game.State.MENU)
	_show_menu()
