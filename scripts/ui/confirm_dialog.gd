extends "res://scripts/ui/modal.gd"
## Yes/No confirmation. Does not touch the game state stack.

var _text: Label
var _yes: Callable
var _yes_btn: Button


func _init() -> void:
	super._init("Confirm", Game.State.PAUSE, false)
	max_size = Vector2(700, 340)


func _build() -> void:
	_text = UI.label("", 22, UI.COL_TEXT, true)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_text)
	var row := HBoxContainer.new()
	body.add_child(row)
	_yes_btn = UI.button("Confirm", func():
		var cb := _yes
		close()
		if cb.is_valid():
			cb.call(), Vector2(0, 58), true)
	_yes_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_yes_btn)
	var no := UI.button("Cancel", close, Vector2(0, 58))
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(no)


func ask(title: String, text: String, on_yes: Callable, yes_label: String = "Confirm") -> void:
	title_label.text = title
	_text.text = text
	_yes = on_yes
	_yes_btn.text = yes_label
	if not is_open:
		is_open = true
		visible = true
		_fit()
		move_to_front()
