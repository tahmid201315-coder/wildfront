extends Control
## Base class for full-screen panels. Handles the dim background, centered frame, title bar,
## state push/pop (so menus pause the simulation and return to the right previous state)
## and blocks input from reaching gameplay while open.

const UI = preload("res://scripts/ui/ui_kit.gd")

signal closed

var title_text: String = ""
var state_id: int = Game.State.PAUSE
var uses_game_state: bool = true
var body: VBoxContainer
var title_label: Label
var frame: PanelContainer
var is_open: bool = false
var max_size: Vector2 = Vector2(1120, 640)


func _init(p_title: String = "", p_state: int = Game.State.PAUSE, p_use_state: bool = true) -> void:
	title_text = p_title
	state_id = p_state
	uses_game_state = p_use_state


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.06, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	frame = PanelContainer.new()
	center.add_child(frame)
	var v := VBoxContainer.new()
	frame.add_child(v)
	var bar := HBoxContainer.new()
	v.add_child(bar)
	title_label = UI.label(title_text, 30, UI.COL_ACCENT)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title_label)
	var cb := UI.button("Close", close, Vector2(120, 52))
	bar.add_child(cb)
	var sep := HSeparator.new()
	v.add_child(sep)
	body = VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	get_viewport().size_changed.connect(_fit)
	_fit()
	_build()


func _fit() -> void:
	if frame == null:
		return
	var vs := get_viewport_rect().size
	frame.custom_minimum_size = Vector2(minf(max_size.x, vs.x - 40.0), minf(max_size.y, vs.y - 30.0))
	frame.size = frame.custom_minimum_size


## Override: build static widgets into `body`.
func _build() -> void:
	pass


## Override: refresh dynamic content.
func refresh() -> void:
	pass


func open() -> void:
	if is_open:
		return
	is_open = true
	visible = true
	if uses_game_state:
		Game.push_state(state_id)
	_fit()
	refresh()
	Sfx.play("click")


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	if uses_game_state:
		Game.pop_state()
	Sfx.play("back")
	closed.emit()


## Force-close without sound (used when the world is torn down).
func force_close() -> void:
	if is_open:
		is_open = false
		visible = false
