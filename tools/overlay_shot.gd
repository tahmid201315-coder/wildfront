extends Node
func snap(n: String) -> void:
	for i in 4:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("/tmp/shots/ov_" + n + ".png")
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/shots/")
	var m: Node = load("res://scenes/main.tscn").instantiate()
	add_child(m)
	m.overlay.instant = false
	m.overlay.intro_len = 2.6
	m.overlay.play_intro()
	m.overlay.t = 0.5
	await snap("intro1")
	m.overlay.t = 1.3
	await snap("intro2")
	m.overlay.t = 2.2
	await snap("intro3")
	m.overlay.end_intro()
	m.menus.visible = true
	m.overlay.mode = "loading"
	m.overlay.t = 1.0
	m.overlay.save_t = 1.0
	await snap("loading")
	m.overlay.mode = ""
	m.overlay.save_t = 1.0
	await snap("saving")
	get_tree().quit()
