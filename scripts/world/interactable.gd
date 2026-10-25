extends Node3D
## Base class for everything the player can interact with (resources, containers, terminals ...).
## Subclasses override get_prompt / can_interact / interact. Registers itself with the world.

var interact_radius: float = 2.6
var enabled: bool = true
var hold_repeat: bool = false        # holding the interact button repeats the action (gathering)
var aim_offset: Vector3 = Vector3(0, 1.0, 0)


func _enter_tree() -> void:
	call_deferred("_register")


func _register() -> void:
	if is_inside_tree() and Game.world and Game.world.has_method("register_interactable"):
		Game.world.register_interactable(self)


func _exit_tree() -> void:
	if Game.world and is_instance_valid(Game.world) and Game.world.has_method("unregister_interactable"):
		Game.world.unregister_interactable(self)


func get_prompt(_player: Node) -> String:
	return "Interact"


func can_interact(_player: Node) -> bool:
	return enabled


func interact(_player: Node) -> void:
	pass


func center() -> Vector3:
	return global_position + aim_offset
