extends Node
## Entry point: owns the Stage and the UI layers and routes game flow (title -> play -> pause -> game over).

var stage: Stage


func _ready() -> void:
	stage = Stage.new()
	add_child(stage)
	var d := LevelData.new()
	d.id = "test"
	d.region = "meadows"
	d.rows = PackedStringArray(["#".repeat(50)])
	d.finalize()
