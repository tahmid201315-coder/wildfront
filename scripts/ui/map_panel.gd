extends "res://scripts/ui/modal.gd"
## World map with fog of war. Only discovered landmarks and real quest locations are shown.

var world: Node = null
var _terrain_img: Image = null
var _tex_rect: TextureRect
var _overlay: Control
const MAP_PX := 120


func _init() -> void:
	super._init("Map of Aetherwild", Game.State.PAUSE, true)


func _build() -> void:
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(500, 500)
	row.add_child(holder)
	_tex_rect = TextureRect.new()
	_tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex_rect.custom_minimum_size = Vector2(500, 500)
	_tex_rect.size = Vector2(500, 500)
	holder.add_child(_tex_rect)
	_overlay = MapOverlay.new()
	_overlay.panel = self
	_overlay.size = Vector2(500, 500)
	_overlay.custom_minimum_size = Vector2(500, 500)
	holder.add_child(_overlay)
	var legend := VBoxContainer.new()
	legend.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(legend)
	legend.add_child(UI.label("Legend", 24, UI.COL_ACCENT))
	legend.add_child(UI.label("White arrow: you\nGold diamond: quest location\nBlue flag: discovered landmark\nBrown square: your buildings\nDark areas: unexplored", 19, UI.COL_TEXT, true))
	legend.add_child(UI.label("Regions", 24, UI.COL_ACCENT))
	for rid in Data.regions:
		var seen: bool = Game.visited_regions.has(rid)
		legend.add_child(UI.label(("%s (visited)" % Data.regions[rid]["name"]) if seen else "Unknown region", 19, Data.regions[rid]["color"] if seen else UI.COL_DIM))
	legend.add_child(UI.label("Quest", 24, UI.COL_ACCENT))
	var t := Quests.tracked()
	legend.add_child(UI.label(Data.quests[t]["name"] if t != "" else "None", 19, UI.COL_TEXT, true))


func _ensure_terrain() -> void:
	if _terrain_img != null or world == null:
		return
	_terrain_img = Image.create(MAP_PX, MAP_PX, false, Image.FORMAT_RGBA8)
	var half := Data.WORLD_HALF
	for pz in MAP_PX:
		for px in MAP_PX:
			var x := -half + (px + 0.5) * (2.0 * half / MAP_PX)
			var z := -half + (pz + 0.5) * (2.0 * half / MAP_PX)
			var h: float = world.height_at(x, z)
			var c := Color(0.35, 0.6, 0.3)
			if x >= Data.EMBER_START_X:
				c = Color(0.65, 0.35, 0.22)
			if h < world.WATER_Y:
				c = Color(0.25, 0.5, 0.75)
			elif h > 6.5:
				c = c.darkened(0.2)
			if maxf(absf(x), absf(z)) > 100.0:
				c = Color(0.4, 0.4, 0.45)
			_terrain_img.set_pixel(px, pz, c.lightened(clampf((h - 3.0) * 0.03, -0.1, 0.15)))


func refresh() -> void:
	if world == null:
		return
	_ensure_terrain()
	var img := _terrain_img.duplicate() as Image
	var fog := Color(0.04, 0.06, 0.08)
	for pz in MAP_PX:
		for px in MAP_PX:
			var ex := px * Game.EXPLORE_N / MAP_PX
			var ez := pz * Game.EXPLORE_N / MAP_PX
			if Game.explored[ez * Game.EXPLORE_N + ex] == 0:
				img.set_pixel(px, pz, fog)
	_tex_rect.texture = ImageTexture.create_from_image(img)
	_overlay.queue_redraw()


func world_to_map(p: Vector3) -> Vector2:
	var half := Data.WORLD_HALF
	return Vector2((p.x + half) / (2.0 * half), (p.z + half) / (2.0 * half)) * _overlay.size


func is_explored(p: Vector3) -> bool:
	var half := Data.WORLD_HALF
	var ex := int((p.x + half) / Game.EXPLORE_CELL)
	var ez := int((p.z + half) / Game.EXPLORE_CELL)
	if ex < 0 or ez < 0 or ex >= Game.EXPLORE_N or ez >= Game.EXPLORE_N:
		return false
	return Game.explored[ez * Game.EXPLORE_N + ex] == 1


class MapOverlay extends Control:
	var panel: Node

	func _draw() -> void:
		if panel == null or panel.world == null:
			return
		var w: Node = panel.world
		# region boundary (only drawn once the player has explored beside it)
		var bx: float = panel.world_to_map(Vector3(Data.EMBER_START_X, 0, 0)).x
		draw_dashed_line(Vector2(bx, 0), Vector2(bx, size.y), Color(1, 1, 1, 0.35), 2.0, 8.0)
		# buildings
		for id in w.build_manager.structures:
			var s: Node = w.build_manager.structures[id]
			if s.type in ["foundation", "chest", "workbench", "campfire", "plot", "rest"]:
				var p: Vector2 = panel.world_to_map(s.global_position)
				draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), Color(0.8, 0.55, 0.3))
		# discovered landmarks
		for id in w.landmark_nodes:
			if Game.found_landmarks.has(id):
				var lp: Vector2 = panel.world_to_map(w.landmark_nodes[id].global_position)
				draw_line(lp, lp + Vector2(0, -16), Color.WHITE, 2.0)
				draw_colored_polygon(PackedVector2Array([lp + Vector2(0, -16), lp + Vector2(11, -12), lp + Vector2(0, -8)]), Color(0.3, 0.7, 1.0))
				draw_string(ThemeDB.fallback_font, lp + Vector2(8, 10), Data.landmarks[id]["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.9))
		# quest markers (real locations only)
		for qid in Quests.active:
			var mk: String = Data.quests[qid]["marker"]
			var mp: Variant = w.marker_pos(mk)
			if mp != null:
				var qp: Vector2 = panel.world_to_map(mp)
				draw_colored_polygon(PackedVector2Array([qp + Vector2(0, -10), qp + Vector2(8, 0), qp + Vector2(0, 10), qp + Vector2(-8, 0)]), Color(1.0, 0.8, 0.2))
				draw_polyline(PackedVector2Array([qp + Vector2(0, -10), qp + Vector2(8, 0), qp + Vector2(0, 10), qp + Vector2(-8, 0), qp + Vector2(0, -10)]), Color(0.2, 0.15, 0.0), 2.0)
		# player arrow
		var pp: Vector2 = panel.world_to_map(w.player.global_position)
		var yaw: float = w.player.facing_yaw
		var f := Vector2(-sin(yaw), -cos(yaw))
		var r := Vector2(-f.y, f.x)
		draw_colored_polygon(PackedVector2Array([pp + f * 11.0, pp - f * 7.0 + r * 7.0, pp - f * 3.0, pp - f * 7.0 - r * 7.0]), Color.WHITE)
		draw_polyline(PackedVector2Array([pp + f * 11.0, pp - f * 7.0 + r * 7.0, pp - f * 3.0, pp - f * 7.0 - r * 7.0, pp + f * 11.0]), Color(0, 0, 0, 0.8), 2.0)
