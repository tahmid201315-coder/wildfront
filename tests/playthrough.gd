extends SceneTree
## Scripted playthrough placeholder: replaced by the full simulated run as systems land.
func _initialize() -> void:
	await process_frame
	print("==== PLAYTHROUGH: 0 passed, 0 failed ====")
	quit(0)
