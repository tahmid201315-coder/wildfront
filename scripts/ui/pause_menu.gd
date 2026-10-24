extends "res://scripts/ui/modal.gd"
## Pause menu: resume, save, journal shortcut, settings, return to main menu.

var hud: Node = null


func _init() -> void:
	super._init("Paused", Game.State.PAUSE, true)
	max_size = Vector2(620, 600)


func _build() -> void:
	body.add_child(UI.button("Resume", close, Vector2(0, 62), true))
	body.add_child(UI.button("Save game", func():
		if hud and hud.world:
			hud.world.manual_save(), Vector2(0, 58)))
	body.add_child(UI.button("Journal", func():
		close()
		hud.open_journal(), Vector2(0, 58)))
	body.add_child(UI.button("Settings", func(): hud.settings_panel.open(), Vector2(0, 58)))
	body.add_child(UI.button("Quit to main menu", func():
		hud.confirm.ask("Quit to main menu?", "Your progress is saved automatically before you leave.", func():
			hud.return_to_menu()), Vector2(0, 58)))
