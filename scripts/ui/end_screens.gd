extends RefCounted
## Full-screen overlays: defeat (respawn) and the ending.

const UI = preload("res://scripts/ui/ui_kit.gd")
const Modal = preload("res://scripts/ui/modal.gd")


static func make_defeat(on_respawn: Callable, on_menu: Callable) -> Control:
	var m: Control = Modal.new("You were defeated", Game.State.DEFEAT, false)
	m.max_size = Vector2(620, 420)
	m.ready.connect(func():
		m.title_label.get_parent().get_child(1).visible = false
		m.title_label.add_theme_color_override("font_color", UI.COL_BAD)
		var col := VBoxContainer.new()
		col.size_flags_vertical = Control.SIZE_EXPAND_FILL
		m.body.add_child(col)
		var l := UI.label("", 22, UI.COL_TEXT, true)
		l.name = "info"
		col.add_child(l)
		col.add_child(UI.spacer(14))
		col.add_child(UI.button("Respawn", func():
			on_respawn.call(), Vector2(0, 62), true))
		col.add_child(UI.button("Quit to Menu", func():
			on_menu.call(), Vector2(0, 56))))
	return m


static func make_ending(on_continue: Callable, on_menu: Callable) -> Control:
	var m: Control = Modal.new("", Game.State.ENDING, false)
	m.max_size = Vector2(900, 560)
	m.ready.connect(func():
		m.title_label.get_parent().get_child(1).visible = false
		var DS = preload("res://scripts/core/data_story.gd")
		m.title_label.text = DS.ENDING_TITLE
		var col := VBoxContainer.new()
		col.size_flags_vertical = Control.SIZE_EXPAND_FILL
		m.body.add_child(col)
		for line in DS.ENDING_LINES:
			col.add_child(UI.label(line, 24, UI.COL_TEXT, true))
			col.add_child(UI.spacer(10))
		col.add_child(UI.label("Quests completed: %d    Level: %d    Days survived: %d" % [Quests.completed.size(), Game.level, Game.day_count], 20, UI.COL_ACCENT))
		col.add_child(UI.spacer(14))
		col.add_child(UI.button("Keep Exploring", func():
			on_continue.call(), Vector2(0, 62), true))
		col.add_child(UI.button("Return to Menu", func():
			on_menu.call(), Vector2(0, 56))))
	return m
