extends Node
func _ready():
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(0.5).timeout
	print("main size ", main.size, " boot size ", main._current.size, " vp ", get_viewport().get_visible_rect().size)
	get_tree().quit()
