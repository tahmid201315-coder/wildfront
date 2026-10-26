extends Node
func _ready():
	for p in ["res://scripts/player/player.gd","res://scripts/player/player_model.gd","res://scripts/world/interactable.gd","res://scripts/world/site_objects.gd","res://scripts/world/sites.gd","res://scripts/enemies/boss.gd","res://scripts/ui/quest_panel.gd","res://scripts/ui/skills_panel.gd","res://scripts/ui/map_panel.gd","res://scripts/ui/log_panel.gd","res://scripts/ui/dialogue_panel.gd","res://scripts/ui/end_screens.gd","res://scripts/world/death_cache.gd","res://scripts/main/session.gd"]:
		var s = load(p)
		print(p, " -> ", "OK" if s != null and s.can_instantiate() else "FAIL")
	get_tree().quit()
