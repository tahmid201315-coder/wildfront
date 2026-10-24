extends Node3D
## A placed structure. Builds its own visuals/collision for its type and owns its saved state.

const CM = preload("res://scripts/creatures/creature_model.gd")

const FUNCTIONAL := ["chest", "workbench", "campfire", "plot", "rest", "door"]
const CROP_GROW_TIME := 150.0       # watered seconds for a Sunberry crop
const WATER_DURATION := 180.0

var sid: String = ""
var type: String = ""
var state: Dictionary = {}
var world: Node = null
var preview: bool = false
var interact_radius: float = 3.2
var _light: OmniLight3D
var _crop_root: Node3D
var _door_leaf: Node3D
var _door_body: CollisionShape3D
var _rest_label: Label3D
var _flicker_t: float = 0.0
var top_y: float = 0.0


func setup(p_world: Node, p_id: String, p_type: String, pos: Vector3, rot_y: float, p_state: Dictionary, as_preview: bool = false) -> void:
	world = p_world
	sid = p_id
	type = p_type
	preview = as_preview
	position = pos
	rotation.y = rot_y
	state = p_state.duplicate(true)
	top_y = pos.y
	_build()
	if not preview and type in FUNCTIONAL:
		add_to_group("interactable")
	if not preview:
		add_to_group("structure")
		_apply_state_visuals()


func _box_body(size: Vector3, center: Vector3, layer: int = 2) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = layer
	b.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = center
	b.add_child(cs)
	add_child(b)
	return b


func _build() -> void:
	var wood := Color(0.62, 0.43, 0.25)
	var wood_d := Color(0.45, 0.3, 0.18)
	match type:
		"foundation":
			CM.part(self, "box", Vector3(4, 1.2, 4), Color(0.6, 0.58, 0.55), Vector3(0, -0.6, 0))
			CM.part(self, "box", Vector3(3.8, 0.08, 3.8), Color(0.7, 0.66, 0.6), Vector3(0, -0.02, 0))
			if not preview:
				_box_body(Vector3(4, 1.2, 4), Vector3(0, -0.6, 0))
		"floor":
			CM.part(self, "box", Vector3(4, 0.7, 4), wood, Vector3(0, -0.35, 0))
			for i in 4:
				CM.part(self, "box", Vector3(3.9, 0.02, 0.05), wood_d, Vector3(0, 0.005, -1.5 + i * 1.0))
			if not preview:
				_box_body(Vector3(4, 0.7, 4), Vector3(0, -0.35, 0))
		"wall":
			CM.part(self, "box", Vector3(4, 3, 0.3), wood, Vector3(0, 1.5, 0))
			for i in 4:
				CM.part(self, "box", Vector3(0.06, 3, 0.34), wood_d, Vector3(-1.5 + i * 1.0, 1.5, 0))
			if not preview:
				_box_body(Vector3(4, 3, 0.3), Vector3(0, 1.5, 0))
		"door":
			CM.part(self, "box", Vector3(1.2, 3, 0.3), wood, Vector3(-1.4, 1.5, 0))
			CM.part(self, "box", Vector3(1.2, 3, 0.3), wood, Vector3(1.4, 1.5, 0))
			CM.part(self, "box", Vector3(1.6, 0.8, 0.3), wood, Vector3(0, 2.6, 0))
			_door_leaf = Node3D.new()
			_door_leaf.position = Vector3(-0.8, 0, 0)
			add_child(_door_leaf)
			CM.part(_door_leaf, "box", Vector3(1.6, 2.2, 0.16), wood_d, Vector3(0.8, 1.1, 0))
			CM.part(_door_leaf, "sphere", Vector3(0.12, 0.12, 0.12), Color(0.9, 0.8, 0.3), Vector3(1.3, 1.1, 0.12))
			if not preview:
				_box_body(Vector3(1.2, 3, 0.3), Vector3(-1.4, 1.5, 0))
				_box_body(Vector3(1.2, 3, 0.3), Vector3(1.4, 1.5, 0))
				var lintel := _box_body(Vector3(1.6, 0.8, 0.3), Vector3(0, 2.6, 0))
				lintel.name = "Lintel"
				var leaf := _box_body(Vector3(1.6, 2.2, 0.16), Vector3(0, 1.1, 0))
				_door_body = leaf.get_child(0)
		"roof":
			var rc := Color(0.72, 0.3, 0.25)
			for s in [-1, 1]:
				CM.part(self, "box", Vector3(4.8, 0.2, 2.9), rc, Vector3(0, 0.0, 1.2 * s), Vector3(26 * s, 0, 0))
			CM.part(self, "box", Vector3(4.8, 0.14, 0.3), rc.darkened(0.3), Vector3(0, 0.64, 0))
		"chest":
			CM.part(self, "box", Vector3(1.1, 0.6, 0.75), wood, Vector3(0, 0.3, 0))
			CM.part(self, "box", Vector3(1.14, 0.22, 0.79), wood_d, Vector3(0, 0.68, 0))
			CM.part(self, "box", Vector3(0.14, 0.2, 0.06), Color(0.9, 0.8, 0.3), Vector3(0, 0.5, -0.4))
			if not preview:
				_box_body(Vector3(1.1, 0.8, 0.75), Vector3(0, 0.4, 0))
		"workbench":
			CM.part(self, "box", Vector3(2.0, 0.14, 0.9), wood, Vector3(0, 0.9, 0))
			for x in [-0.85, 0.85]:
				for z in [-0.35, 0.35]:
					CM.part(self, "box", Vector3(0.12, 0.9, 0.12), wood_d, Vector3(x, 0.45, z))
			CM.part(self, "box", Vector3(0.5, 0.08, 0.3), Color(0.6, 0.62, 0.65), Vector3(0.4, 1.0, 0))
			CM.part(self, "box", Vector3(0.1, 0.35, 0.1), wood_d, Vector3(-0.5, 1.1, 0.1), Vector3(0, 0, 70))
			if not preview:
				_box_body(Vector3(2.0, 1.0, 0.9), Vector3(0, 0.5, 0))
		"campfire":
			for i in 8:
				var a := TAU * i / 8.0
				CM.part(self, "sphere", Vector3(0.28, 0.2, 0.28), Color(0.5, 0.5, 0.52), Vector3(cos(a) * 0.55, 0.1, sin(a) * 0.55))
			CM.part(self, "cyl", Vector3(0.12, 0.8, 0.12), wood_d, Vector3(0, 0.15, 0), Vector3(0, 0, 70))
			CM.part(self, "cyl", Vector3(0.12, 0.8, 0.12), wood_d, Vector3(0, 0.15, 0), Vector3(70, 0, 0))
			var fl := CM.part(self, "cone", Vector3(0.4, 0.8, 0.4), Color(1.0, 0.55, 0.15), Vector3(0, 0.55, 0), Vector3.ZERO, 3.0)
			fl.name = "Flame"
			if not preview:
				_box_body(Vector3(1.0, 0.5, 1.0), Vector3(0, 0.25, 0))
				_add_light(Color(1.0, 0.6, 0.25), 5.0, 1.6)
		"plot":
			CM.part(self, "box", Vector3(2.4, 0.22, 2.4), Color(0.32, 0.22, 0.15), Vector3(0, 0.11, 0))
			for s in [-1, 1]:
				CM.part(self, "box", Vector3(2.6, 0.3, 0.12), wood, Vector3(0, 0.15, 1.25 * s))
				CM.part(self, "box", Vector3(0.12, 0.3, 2.6), wood, Vector3(1.25 * s, 0.15, 0))
			_crop_root = Node3D.new()
			_crop_root.position = Vector3(0, 0.22, 0)
			add_child(_crop_root)
			for i in 5:
				var cx := -0.7 + (i % 3) * 0.7 if i < 3 else -0.35 + (i - 3) * 0.7
				var cz := -0.5 if i < 3 else 0.5
				CM.part(_crop_root, "cone", Vector3(0.3, 0.5, 0.3), Color(0.3, 0.65, 0.3), Vector3(cx, 0.25, cz))
				CM.part(_crop_root, "sphere", Vector3(0.14, 0.14, 0.14), Color(0.9, 0.15, 0.25), Vector3(cx, 0.55, cz), Vector3.ZERO, 0.3)
			_crop_root.visible = false
		"lamp":
			CM.part(self, "cyl", Vector3(0.08, 1.6, 0.08), wood_d, Vector3(0, 0.8, 0))
			CM.part(self, "sphere", Vector3(0.35, 0.35, 0.35), Color(1.0, 0.9, 0.5), Vector3(0, 1.7, 0), Vector3.ZERO, 2.5)
			if not preview:
				_box_body(Vector3(0.3, 1.6, 0.3), Vector3(0, 0.8, 0))
				_add_light(Color(1.0, 0.88, 0.55), 7.0, 1.2)
		"rest":
			CM.part(self, "box", Vector3(2.0, 0.14, 2.0), Color(0.5, 0.7, 0.55), Vector3(0, 0.07, 0))
			CM.part(self, "sphere", Vector3(1.2, 0.35, 0.8), Color(0.85, 0.8, 0.65), Vector3(0, 0.3, 0.1))
			for s in [-1, 1]:
				CM.part(self, "cyl", Vector3(0.08, 1.6, 0.08), wood_d, Vector3(0.9 * s, 0.9, -0.9))
			CM.part(self, "box", Vector3(2.1, 0.08, 1.2), Color(0.35, 0.6, 0.5), Vector3(0, 1.7, -0.9), Vector3(-12, 0, 0))
			_rest_label = Label3D.new()
			_rest_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			_rest_label.pixel_size = 0.01
			_rest_label.font_size = 36
			_rest_label.outline_size = 10
			_rest_label.position = Vector3(0, 2.3, 0)
			_rest_label.visible = false
			add_child(_rest_label)
			if not preview:
				_box_body(Vector3(1.4, 0.4, 1.0), Vector3(0, 0.2, 0.1))


func _add_light(col: Color, range_m: float, energy: float) -> void:
	_light = OmniLight3D.new()
	_light.light_color = col
	_light.omni_range = range_m
	_light.light_energy = energy
	_light.position = Vector3(0, 1.0, 0)
	_light.shadow_enabled = false
	add_child(_light)


# ------------------------------------------------------------ interactable interface
func get_prompt() -> String:
	match type:
		"chest": return "Open Chest"
		"workbench": return "Use Workbench"
		"campfire": return "Use Campfire"
		"plot":
			if str(state.get("crop", "")) == "":
				return "Tend Plot (plant)"
			if _is_ready():
				return "Harvest Crop"
			return "Tend Plot"
		"rest": return "Creature Rest Station"
		"door": return "Close Door" if bool(state.get("open", false)) else "Open Door"
	return ""


func can_interact(_player: Node) -> bool:
	return type in FUNCTIONAL


func interact(player: Node) -> void:
	match type:
		"chest": world.hud.open_chest(self)
		"workbench": world.hud.open_crafting("workbench")
		"campfire": world.hud.open_crafting("campfire")
		"plot": world.hud.open_plot(self)
		"rest": world.hud.open_rest(self)
		"door":
			state["open"] = not bool(state.get("open", false))
			_apply_state_visuals()
			Sfx.play("click")
			if player.has_method("begin_interact"):
				player.begin_interact()


# ------------------------------------------------------------ state-driven visuals
func _apply_state_visuals() -> void:
	match type:
		"door":
			var open := bool(state.get("open", false))
			if _door_leaf:
				_door_leaf.rotation.y = -PI * 0.5 if open else 0.0
			if _door_body:
				_door_body.set_deferred("disabled", open)
		"plot":
			_update_crop_visual()
		"rest":
			_update_rest_label()


# ---- farming
func _is_ready() -> bool:
	return str(state.get("crop", "")) != "" and float(state.get("growth", 0.0)) >= CROP_GROW_TIME


func plant(seed_id: String) -> bool:
	if str(state.get("crop", "")) != "":
		return false
	var crop: String = str(Data.get_item(seed_id).get("crop", ""))
	if crop == "" or not Inv.remove(seed_id, 1):
		return false
	state["crop"] = crop
	state["growth"] = 0.0
	state["water"] = 0.0
	_update_crop_visual()
	return true


func water_plot(amount: float = WATER_DURATION) -> void:
	if str(state.get("crop", "")) != "":
		state["water"] = maxf(float(state.get("water", 0.0)), amount)


func harvest() -> bool:
	if not _is_ready():
		return false
	var crop: String = str(state["crop"])
	var yield_n := 4
	Game.give_item(crop, yield_n)
	if randf() < 0.5:
		Game.give_item("seed_berry", 1)
	state["crop"] = ""
	state["growth"] = 0.0
	state["water"] = 0.0
	Quests.notify_event("harvest", crop, 1)
	Game.add_xp(15, "harvest")
	_update_crop_visual()
	Sfx.play("pickup")
	return true


func _update_crop_visual() -> void:
	if _crop_root == null:
		return
	var crop := str(state.get("crop", ""))
	_crop_root.visible = crop != ""
	if crop != "":
		var f := clampf(float(state.get("growth", 0.0)) / CROP_GROW_TIME, 0.0, 1.0)
		_crop_root.scale = Vector3.ONE * lerpf(0.25, 1.0, f)


## Called about once per second by the world while the plot is loaded and the game is running.
func tick(dt: float, growth_mult: float) -> void:
	match type:
		"plot":
			if str(state.get("crop", "")) == "":
				return
			var w := float(state.get("water", 0.0))
			if w > 0.0:
				var used := minf(w, dt)
				state["water"] = w - used
				if not _is_ready():
					state["growth"] = minf(float(state.get("growth", 0.0)) + used * growth_mult, CROP_GROW_TIME)
					_update_crop_visual()
		"rest":
			_tick_rest(dt)


# ---- creature-assisted production
func assign_creature(uid: String) -> bool:
	var c := Game.find_creature(uid)
	if c.is_empty() or uid == Game.active_uid:
		return false
	if not Data.creatures[c["species"]].get("work", {}).has("item"):
		return false
	if str(state.get("uid", "")) != "":
		unassign()
	state["uid"] = uid
	state["progress"] = 0.0
	state["stored"] = int(state.get("stored", 0))
	c["assigned"] = sid
	Game.collection_changed.emit()
	_update_rest_label()
	return true


func unassign() -> void:
	var uid := str(state.get("uid", ""))
	if uid != "":
		var c := Game.find_creature(uid)
		if not c.is_empty():
			c["assigned"] = ""
	state["uid"] = ""
	state["progress"] = 0.0
	Game.collection_changed.emit()
	_update_rest_label()


func _work_def() -> Dictionary:
	var c := Game.find_creature(str(state.get("uid", "")))
	if c.is_empty():
		return {}
	return Data.creatures[c["species"]].get("work", {})


func _tick_rest(dt: float) -> void:
	var wd := _work_def()
	if wd.is_empty():
		if str(state.get("uid", "")) != "":
			state["uid"] = ""  # creature was released
		return
	if int(state.get("stored", 0)) >= int(wd["cap"]):
		return
	state["progress"] = float(state.get("progress", 0.0)) + dt
	if float(state["progress"]) >= float(wd["interval"]):
		state["progress"] = 0.0
		state["stored"] = mini(int(state.get("stored", 0)) + 1, int(wd["cap"]))
		_update_rest_label()


func collect_work() -> int:
	var wd := _work_def()
	var n := int(state.get("stored", 0))
	if wd.is_empty() or n <= 0:
		return 0
	Game.give_item(wd["item"], n)
	state["stored"] = 0
	_update_rest_label()
	return n


func work_progress() -> float:
	var wd := _work_def()
	if wd.is_empty():
		return 0.0
	return clampf(float(state.get("progress", 0.0)) / float(wd["interval"]), 0.0, 1.0)


func _update_rest_label() -> void:
	if _rest_label == null:
		return
	var c := Game.find_creature(str(state.get("uid", "")))
	if c.is_empty():
		_rest_label.visible = false
		return
	_rest_label.visible = true
	_rest_label.text = "%s resting (%d stored)" % [c["name"], int(state.get("stored", 0))]


func _process(delta: float) -> void:
	if _light != null and not preview:
		_flicker_t += delta
		if type == "campfire":
			_light.light_energy = 1.5 + sin(_flicker_t * 13.0) * 0.25 + sin(_flicker_t * 7.0) * 0.15
			var fl := get_node_or_null("Flame")
			if fl:
				fl.scale = Vector3(0.4, 0.8 + sin(_flicker_t * 11.0) * 0.12, 0.4)
		elif type == "lamp" and world != null:
			_light.visible = world.is_night()


func serialize() -> Dictionary:
	return {"id": sid, "type": type, "pos": [position.x, position.y, position.z], "rot": rotation.y, "state": state.duplicate(true)}
