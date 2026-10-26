extends "res://scripts/ui/modal.gd"
## Short conversation scenes from Data.dialogues. Tap Next to advance.

var _lines: Array = []
var _i: int = 0
var _speaker: Label
var _text: Label
var _next: Button
var _on_done: Callable = Callable()


func _init() -> void:
	super._init("", Game.State.DIALOGUE, true)
	max_size = Vector2(820, 380)


func _build() -> void:
	_speaker = UI.label("", 26, UI.COL_ACCENT)
	body.add_child(_speaker)
	body.add_child(UI.spacer(6))
	_text = UI.label("", 24, UI.COL_TEXT, true)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_text)
	_next = UI.button("Next", _advance, Vector2(0, 58), true)
	body.add_child(_next)


func play(id: String, on_done: Callable = Callable()) -> void:
	if not Data.dialogues.has(id):
		return
	_lines = Data.dialogues[id]
	_i = 0
	_on_done = on_done
	open()


func refresh() -> void:
	if _i >= _lines.size():
		return
	_speaker.text = _lines[_i][0]
	_text.text = _lines[_i][1]
	_next.text = "Next" if _i < _lines.size() - 1 else "Close"


func _advance() -> void:
	_i += 1
	if _i >= _lines.size():
		close()
		if _on_done.is_valid():
			_on_done.call()
	else:
		refresh()
