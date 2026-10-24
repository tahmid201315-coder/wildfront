extends Node3D
## A discoverable landmark. Reading its inscription unlocks lore; the shrine can be restored.

const CM = preload("res://scripts/creatures/creature_model.gd")

var lid: String = ""
var world: Node = null
var interact_radius: float = 3.6
var core_restored: bool = false
var _glow: MeshInstance3D


func setup(p_world: Node, id: String, pos: Vector3) -> void:
	world = p_world
	lid = id
	position = pos
	_build()
	if lid != "camp":
		add_to_group("interactable")


func _stone_body(size: Vector3, center: Vector3) -> void:
	var b := StaticBody3D.new()
	b.collision_layer = 1
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = center
	b.add_child(cs)
	add_child(b)


func _build() -> void:
	var stone := Color(0.55, 0.55, 0.58)
	var dark := Color(0.2, 0.17, 0.17)
	var wood := Color(0.5, 0.35, 0.2)
	match lid:
		"camp":
			CM.part(self, "box", Vector3(2.6, 0.08, 2.2), Color(0.5, 0.42, 0.3), Vector3(0, 0.04, 0))
			for s in [-1, 1]:
				CM.part(self, "box", Vector3(2.4, 0.08, 1.9), Color(0.85, 0.75, 0.5), Vector3(0, 0.95, 0.85 * s), Vector3(-38 * s, 0, 0))
			CM.part(self, "cyl", Vector3(0.7, 0.4, 0.7), wood, Vector3(2.4, 0.2, 1.2))
			CM.part(self, "box", Vector3(0.1, 1.2, 0.1), wood, Vector3(-2.4, 0.6, 1.4))
			CM.part(self, "box", Vector3(0.9, 0.45, 0.08), Color(0.7, 0.55, 0.35), Vector3(-2.4, 1.15, 1.4))
		"old_marker":
			CM.part(self, "cyl", Vector3(1.6, 0.4, 1.6), stone, Vector3(0, 0.2, 0))
			CM.part(self, "box", Vector3(0.5, 3.4, 0.5), wood, Vector3(0, 2.0, 0))
			CM.part(self, "cyl", Vector3(0.9, 0.08, 0.9), Color(0.9, 0.8, 0.4), Vector3(0, 2.6, 0.27), Vector3(90, 0, 0), 0.6)
			for i in 4:
				CM.part(self, "sphere", Vector3(0.12, 0.12, 0.12), Color(0.9, 0.8, 0.4), Vector3(-0.25 + i * 0.17, 1.8, 0.27), Vector3.ZERO, 0.6)
			_stone_body(Vector3(1.6, 1.0, 1.6), Vector3(0, 0.5, 0))
		"watchtower":
			for p in [Vector2(-1.5, -1.5), Vector2(1.5, -1.5), Vector2(1.5, 1.5)]:
				CM.part(self, "box", Vector3(0.45, 4.5 if p.x > 0 else 2.5, 0.45), wood, Vector3(p.x, 2.0, p.y), Vector3(0, 0, (6 if p.y < 0 else -4)))
			CM.part(self, "box", Vector3(3.6, 0.2, 3.6), wood.darkened(0.2), Vector3(0, 1.0, 0), Vector3(4, 0, 6))
			CM.part(self, "box", Vector3(2.0, 0.15, 0.5), wood, Vector3(2.5, 0.1, 2.5), Vector3(0, 30, 80))
			_stone_body(Vector3(3.0, 1.0, 3.0), Vector3(0, 0.5, 0))
		"ember_gate":
			for s in [-1, 1]:
				CM.part(self, "box", Vector3(1.1, 5.0, 1.1), dark, Vector3(3.2 * s, 2.5, 0))
				CM.part(self, "box", Vector3(0.9, 0.12, 0.12), Color(1.0, 0.5, 0.15), Vector3(3.2 * s, 3.2, 0.57), Vector3.ZERO, 2.5)
				CM.part(self, "box", Vector3(0.9, 0.12, 0.12), Color(1.0, 0.5, 0.15), Vector3(3.2 * s, 2.2, 0.57), Vector3.ZERO, 2.5)
				_stone_body(Vector3(1.1, 5.0, 1.1), Vector3(3.2 * s, 2.5, 0))
			CM.part(self, "box", Vector3(8.0, 0.8, 1.1), dark.lightened(0.05), Vector3(0, 5.4, 0))
			CM.part(self, "box", Vector3(1.4, 1.2, 0.5), Color(0.9, 0.9, 0.85), Vector3(0, 0.6, 3.3))
		"hollow":
			for i in 10:
				var a := TAU * i / 10.0
				CM.part(self, "cone", Vector3(0.9, 3.2 + (i % 3) * 0.6, 0.9), Color(0.82, 0.78, 0.68), Vector3(cos(a) * 13.0, 1.6, sin(a) * 13.0), Vector3(cos(a) * 12, 0, sin(a) * 12))
			CM.part(self, "cyl", Vector3(26, 0.1, 26), Color(0.32, 0.22, 0.2), Vector3(0, 0.05, 0))
			interact_radius = 4.5
		"shrine":
			CM.part(self, "cyl", Vector3(3.6, 0.6, 3.6), stone, Vector3(0, 0.3, 0))
			CM.part(self, "cyl", Vector3(2.4, 0.7, 2.4), stone.darkened(0.2), Vector3(0, 0.85, 0))
			for i in 3:
				var a2 := TAU * i / 3.0
				CM.part(self, "box", Vector3(0.4, 0.15, 0.4), Color(0.2, 0.2, 0.22), Vector3(cos(a2) * 0.8, 1.22, sin(a2) * 0.8))
			_glow = CM.part(self, "sphere", Vector3(0.7, 0.7, 0.7), Color(1.0, 0.55, 0.2), Vector3(0, 2.4, 0), Vector3.ZERO, 3.0)
			_glow.visible = false
			for s in [-1, 1]:
				CM.part(self, "box", Vector3(0.6, 3.0, 0.6), stone, Vector3(2.6 * s, 1.5, 0))
			_stone_body(Vector3(3.6, 1.2, 3.6), Vector3(0, 0.6, 0))
			interact_radius = 4.2


func get_prompt() -> String:
	if lid == "hollow":
		return ""
	if lid == "shrine":
		return "Wildcore Shrine (restored)" if core_restored else "Place Ember Shards (%d/3)" % mini(Inv.count("ember_shard"), 3)
	return "Read: " + Data.landmarks[lid]["name"]


func can_interact(_player: Node) -> bool:
	return lid != "hollow" and not (lid == "shrine" and core_restored and false)


func interact(player: Node) -> void:
	if lid == "shrine" and not core_restored:
		if Inv.count("ember_shard") >= 3 and Inv.remove("ember_shard", 3):
			restore_core(true)
			if player.has_method("celebrate"):
				player.celebrate()
			return
		Game.toast("The shrine needs 3 Ember Shards. You have %d." % Inv.count("ember_shard"), "info")
		Sfx.play("invalid")
		return
	Game.unlock_lore(Data.landmarks[lid]["lore"])
	var key: String = "core_restored" if (lid == "shrine" and core_restored) else Data.landmarks[lid]["lore"]
	world.hud.open_lore(key)
	if player.has_method("begin_interact"):
		player.begin_interact()


func restore_core(announce: bool) -> void:
	core_restored = true
	if _glow:
		_glow.visible = true
	if announce:
		Game.unlock_lore("core_restored")
		Quests.notify_event("restore_core", "", 1)
		Game.add_xp(100, "wildcore")
		Game.toast("The Wildcore Shrine awakens!", "quest")
		Sfx.play("levelup")
		world.spawn_burst(global_position + Vector3(0, 2.4, 0), Color(1.0, 0.6, 0.2), 30)
		world.save_now(false)


func _process(delta: float) -> void:
	if _glow and _glow.visible:
		_glow.position.y = 2.4 + sin(Time.get_ticks_msec() * 0.002) * 0.15
		_glow.rotation.y += delta
