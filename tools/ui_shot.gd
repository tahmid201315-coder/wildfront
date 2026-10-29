extends Node
## Developer tool: boots the real game flow and saves PNGs of the main screens to /tmp/shots/ui_*.png
const OUT := "/tmp/shots/"
var m: Node

func snap(n: String) -> void:
	for i in 6:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(OUT + "ui_" + n + ".png")

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	m = load("res://scenes/main.tscn").instantiate()
	add_child(m)
	await snap("title")
	m.menus.show_slots(true)
	await snap("slots")
	m.menus.show_achievements()
	await snap("ach")
	m.menus.show_difficulty(0)
	await snap("difficulty")
	m._on_new_game(0, 1)
	await snap("cutscene")
	m.cutscene.skip()
	await get_tree().create_timer(0.5).timeout
	for i in 90:
		await get_tree().physics_frame
	await snap("play")
	Game.give_equipment("windrunner_boots")
	m.menus.show_pause()
	await snap("pause")
	m.menus.show_settings()
	await snap("settings")
	m.menus.show_inventory()
	await snap("inventory")
	m.menus.show_skills()
	await snap("skills")
	m.menus.show_map()
	await snap("map")
	m.menus.show_gameover()
	await snap("gameover")
	get_tree().quit()
