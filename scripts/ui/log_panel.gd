extends "res://scripts/ui/modal.gd"
## Reader for a single research log opened from a terminal.

var _title: Label
var _author: Label
var _text: Label


func _init() -> void:
	super._init("Research Log", Game.State.PAUSE, true)
	max_size = Vector2(860, 560)


func _build() -> void:
	_title = UI.label("", 28, UI.COL_ACCENT, true)
	body.add_child(_title)
	_author = UI.label("", 18, UI.COL_DIM, true)
	body.add_child(_author)
	body.add_child(UI.spacer(6))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(sc)
	_text = UI.label("", 22, UI.COL_TEXT, true)
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_text)


func show_log(id: String) -> void:
	if not Data.logs.has(id):
		return
	var d: Dictionary = Data.logs[id]
	_title.text = d["title"]
	_author.text = d["author"]
	_text.text = d["text"]
	open()
