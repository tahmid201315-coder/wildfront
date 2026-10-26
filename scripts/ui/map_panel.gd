extends "res://scripts/ui/modal.gd"
## Island map: terrain image, fog of war from exploration, discovered sites, waypoint and player marker.
## Tap the map to place a waypoint.

const WG = preload("res://scripts/world/world_gen.gd")
const DW = preload("res://scripts/core/data_world.gd")
const MAP_PX := 160

static var _terrain_tex: ImageTexture = null

var canvas: Control
var _fog_tex: ImageTexture
var _wp_btn: Button
var _info: Label


func _init() -> void:
	super._init("Map", Game.State.PAUSE, true)
	max_size = Vector2(1100, 680)


static func terrain_texture() -> ImageTexture:
	if _terrain_tex != null:
		return _terrain_tex
	var img := Image.create(MAP_PX, MAP_PX, false, Image.FORMAT_RGB8)
	var half := DW.WORLD_SIZE * 0.5
	for j in MAP_PX:
		for i in MAP_PX:
			var x := (float(i) + 0.5) / MAP_PX * DW.WORLD_SIZE - half
			var z := (float(j) + 0.5) / MAP_PX * DW.WORLD_SIZE - half
			var h := WG.height_at(x, z)
			var c: Color
			if h < -0.3:
				c = Color(0.16, 0.36, 0.55).lerp(Color(0.08, 0.2, 0.38), clampf(-h / 12.0, 0.0, 1.0))
			elif h < 1.0:
				c = Color(0.86, 0.8, 0.6)
			else:
				var r := WG.region_at(x, z)
				var base: Color
				match r:
					"coast": base = Color(0.5, 0.7, 0.36)
					"forest": base = Color(0.24, 0.5, 0.26)
					"highlands": base = Color(0.52, 0.52, 0.5)
					"ashen": base = Color(0.3, 0.26, 0.26)
					"core": base = Color(0.42, 0.4, 0.55)
					_: base = Color(0.4, 0.6, 0.35)
				c = base.lightened(clampf((h - 6.0) / 70.0, 0.0, 0.35))
			img.set_pixel(i, j, c)
	_terrain_tex = ImageTexture.create_from_image(img)
	return _terrain_tex


func _build() -> void:
	canvas = Control.new()
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.custom_minimum_size = Vector2(300, 300)
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.draw.connect(_draw_map)
	canvas.gui_input.connect(_on_input)
	body.add_child(canvas)
	var row := HBoxContainer.new()
	body.add_child(row)
	_info = UI.label("Tap the map to set a waypoint.", 18, UI.COL_DIM)
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_info)
	_wp_btn = UI.button("Clear waypoint", func():
		Game.waypoint = null
		canvas.queue_redraw()
		refresh(), Vector2(220, 48))
	row.add_child(_wp_btn)


func refresh() -> void:
	if canvas == null:
		return
	_wp_btn.disabled = Game.waypoint == null
	_rebuild_fog()
	canvas.queue_redraw()


func _rebuild_fog() -> void:
	var n := Game.EXPLORE_N
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for z in n:
		for x in n:
			img.set_pixel(x, z, Color(0.02, 0.04, 0.05, 0.0) if Game.explored[z * n + x] == 1 else Color(0.02, 0.04, 0.05, 0.93))
	_fog_tex = ImageTexture.create_from_image(img)


func _rect() -> Rect2:
	var s := minf(canvas.size.x, canvas.size.y)
	return Rect2((canvas.size - Vector2(s, s)) * 0.5, Vector2(s, s))


func _w2m(x: float, z: float) -> Vector2:
	var r := _rect()
	return r.position + Vector2((x / DW.WORLD_SIZE + 0.5) * r.size.x, (z / DW.WORLD_SIZE + 0.5) * r.size.y)


func _on_input(ev: InputEvent) -> void:
	var pos := Vector2.ZERO
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		pos = ev.position
	elif ev is InputEventScreenTouch and ev.pressed:
		pos = ev.position
	else:
		return
	var r := _rect()
	if not r.has_point(pos):
		return
	var f := (pos - r.position) / r.size
	Game.waypoint = Vector2((f.x - 0.5) * DW.WORLD_SIZE, (f.y - 0.5) * DW.WORLD_SIZE)
	Sfx.play("click")
	_info.text = "Waypoint set."
	refresh()


func _draw_map() -> void:
	var r := _rect()
	canvas.draw_rect(r.grow(4), Color(0.02, 0.03, 0.04))
	canvas.draw_texture_rect(terrain_texture(), r, false)
	if _fog_tex:
		canvas.draw_texture_rect(_fog_tex, r, false)
	canvas.draw_rect(r, Color(1, 1, 1, 0.4), false, 2.0)
	var font := ThemeDB.fallback_font
	# region names once visited
	for id in DW.REGION_ORDER:
		if Game.regions_seen.has(id):
			var c: Vector2 = DW.REGIONS[id]["center"]
			var p := _w2m(c.x, c.y)
			var nm: String = DW.REGIONS[id]["name"]
			var w := font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
			canvas.draw_string_outline(font, p - Vector2(w * 0.5, 0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 5, Color(0, 0, 0, 0.8))
			canvas.draw_string(font, p - Vector2(w * 0.5, 0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 1, 1, 0.85))
	# sites
	for id in Game.sites_found:
		if not DW.SITES.has(id):
			continue
		var sp: Vector2 = DW.SITES[id]["pos"]
		var p2 := _w2m(sp.x, sp.y)
		canvas.draw_circle(p2, 6, Color(0.1, 0.1, 0.1))
		canvas.draw_circle(p2, 4, UI.COL_ACCENT)
	# tracked quest marker
	var tq: String = Quests.tracked_id
	if tq != "" and Data.quests.has(tq):
		var mk: String = Data.quests[tq]["marker"]
		if mk != "" and DW.SITES.has(mk):
			var mp: Vector2 = DW.SITES[mk]["pos"]
			var q := _w2m(mp.x, mp.y)
			var pulse := 9.0 + 3.0 * sin(Time.get_ticks_msec() * 0.006)
			canvas.draw_arc(q, pulse, 0, TAU, 20, UI.COL_ACCENT2, 3.0)
			canvas.draw_string_outline(font, q + Vector2(12, 5), "Objective", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 5, Color(0, 0, 0, 0.9))
			canvas.draw_string(font, q + Vector2(12, 5), "Objective", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UI.COL_ACCENT2)
	# waypoint
	if Game.waypoint != null:
		var wp: Vector2 = Game.waypoint
		var wq := _w2m(wp.x, wp.y)
		canvas.draw_line(wq, wq + Vector2(0, -22), Color(1, 0.4, 0.4), 3.0)
		canvas.draw_colored_polygon(PackedVector2Array([wq + Vector2(0, -22), wq + Vector2(14, -17), wq + Vector2(0, -11)]), Color(1, 0.4, 0.4))
	# respawn point
	if Game.respawn_pos != Vector3.ZERO:
		var rp := _w2m(Game.respawn_pos.x, Game.respawn_pos.z)
		canvas.draw_rect(Rect2(rp - Vector2(4, 4), Vector2(8, 8)), Color(0.95, 0.55, 0.2))
	# player
	if Game.world and Game.world.player:
		var pl: Node3D = Game.world.player
		var pp := _w2m(pl.global_position.x, pl.global_position.z)
		var yaw: float = pl.facing_yaw
		var fwd := Vector2(-sin(yaw), -cos(yaw))
		var side := Vector2(-fwd.y, fwd.x)
		canvas.draw_colored_polygon(PackedVector2Array([pp + fwd * 11, pp - fwd * 7 + side * 7, pp - fwd * 4, pp - fwd * 7 - side * 7]), Color(1, 1, 1))
		canvas.draw_polyline(PackedVector2Array([pp + fwd * 11, pp - fwd * 7 + side * 7, pp - fwd * 4, pp - fwd * 7 - side * 7, pp + fwd * 11]), Color(0, 0, 0), 2.0)


func _process(_d: float) -> void:
	if is_open and canvas:
		canvas.queue_redraw()
