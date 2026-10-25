extends Node
func _ready():
	for p in ["res://scripts/player/player.gd","res://scripts/player/player_model.gd","res://scripts/world/interactable.gd"]:
		var s = load(p)
		print(p, " -> ", "OK" if s != null and s.can_instantiate() else "FAIL")
	get_tree().quit()
