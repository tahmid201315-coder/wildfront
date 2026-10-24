extends Node3D
## The Aetherwild world: terrain, resources, creatures, landmarks, day/night, saving.
## Everything is generated deterministically from fixed seeds, so there are no external assets
## and the layout is identical on every launch.

const WATER_Y := 0.1
const GRID := 120
const CELL := 2.0
const DAY_LENGTH := 720.0
const AUTOSAVE_SECONDS := 120.0

const CM = preload("res://scripts/creatures/creature_model.gd")
const ResourceNode = preload("res://scripts/world/resource_node.gd")
const Creature = preload("res://scripts/creatures/creature.gd")
const Landmark = preload("res://scripts/world/landmark.gd")
const BuildManager = preload("res://scripts/building/build_manager.gd")
const PlayerScript = preload("res://scripts/player/player.gd")
const Hud = preload("res://scripts/ui/hud.gd")

var noise: FastNoiseLite
var ridge: FastNoiseLite
var player: CharacterBody3D
var hud: Node
var build_manager: Node3D
var structures_root: Node3D
var resources_root: Node3D
var creatures_root: Node3D
var pickups_root: Node3D
var fx_root: Node3D
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial

var resource_nodes: Array = []
var resource_by_id: Dictionary = {}
var wild_creatures: Array = []
var spawn_table: Array = []
var companion_node: Node3D = null
var _companion_uid_spawned: String = "<none>"
var landmark_nodes: Dictionary = {}
var lm_flat: Array = []
var pickups: Array = []
var depleted_nodes: Array = []
var revealed: Dictionary = {}
var obstacle_hash: Dictionary = {}
var hostile_boss: Node = null

var time_of_day: float = 0.06
var world_time: float = 0.0
var current_region: String = ""
var _env_t: float = 0.0
var _tick1: float = 0.0
var _tick_half: float = 0.0
var _autosave_t: float = 0.0
var _burst_count: int = 0
var _float_count: int = 0
var _burst_mesh: SphereMesh
var _loaded_ok: bool = false
var no_autosave: bool = false      # tests can disable file writes


func _ready() -> void:
	Game.world = self
	_setup_noise()
	_compute_landmark_flatten()
	_build_environment()
	_build_terrain()
	_build_water()
	for n in ["Structures", "Resources", "Creatures", "Pickups", "Fx"]:
		var r := Node3D.new()
		r.name = n
		add_child(r)
	structures_root = get_node("Structures")
	resources_root = get_node("Resources")
	creatures_root = get_node("Creatures")
	pickups_root = get_node("Pickups")
	fx_root = get_node("Fx")
	build_manager = BuildManager.new()
	build_manager.name = "BuildManager"
	build_manager.world = self
	add_child(build_manager)
	_build_decor()
	_build_landmarks()
	_populate_resources()
	_build_spawn_table()
	player = PlayerScript.new()
	player.name = "Player"
	player.world = self
	add_child(player)
	hud = Hud.new()
	hud.name = "HUD"
	add_child(hud)
	hud.setup(self)
	Game.companion_changed.connect(_on_companion_changed)
	Game.settings_changed.connect(apply_quality)
	Game.state_changed.connect(_on_state_changed)
	apply_quality()
	var start := Vector3(0, height_at(0, 0) + 1.0, 0)
	player.place_at(start)
	player.cam_yaw = -PI * 0.5
	player.cam_yaw_target = -PI * 0.5
	player.facing_yaw = -PI * 0.5
	_loaded_ok = false
	if Game.pending_continue:
		_loaded_ok = _load_from_disk()
		Game.pending_continue = false
	if not _loaded_ok:
		_new_game_setup()
	_spawn_wild_creatures()
	_sync_companion()
	_update_environment()
	current_region = Data.region_at(player.global_position.x, player.global_position.z)
	Game.visit_region(current_region)
	Game.visit_landmark("camp")
	Game.reveal_area(player.global_position.x, player.global_position.z, 20.0)
	Game.clear_state_stack()
	Game.set_state(Game.State.PLAY)
	Sfx.play_music("ember" if current_region == "ember" else "explore")
	Sfx.play_ambience(true)
	Quests.refresh_unlocks(false)


func _exit_tree() -> void:
	if Game.world == self:
		Game.world = null
	if Game.companion_changed.is_connected(_on_companion_changed):
		Game.companion_changed.disconnect(_on_companion_changed)
	if Game.settings_changed.is_connected(apply_quality):
		Game.settings_changed.disconnect(apply_quality)
	if Game.state_changed.is_connected(_on_state_changed):
		Game.state_changed.disconnect(_on_state_changed)


func _new_game_setup() -> void:
	Inv.clear()
	Quests.reset()
	Inv.add("berries", 3)
	time_of_day = 0.06
	Game.toast("Welcome to Aetherwild! Drag the left side to move, the right side to look.", "info")


# ------------------------------------------------------------ terrain
func _setup_noise() -> void:
	noise = FastNoiseLite.new()
	noise.seed = 1337
	noise.frequency = 0.011
	noise.fractal_octaves = 3
	ridge = FastNoiseLite.new()
	ridge.seed = 77
	ridge.frequency = 0.03
	ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridge.fractal_octaves = 2


func _raw_height(x: float, z: float) -> float:
	var h := noise.get_noise_2d(x, z) * 5.0 + 3.0
	var e := smoothstep(40.0, 64.0, x)
	if e > 0.0:
		h += e * (3.0 + (ridge.get_noise_2d(x, z) + 1.0) * 5.0)
	# river (meadow only)
	var rz := 40.0 + 7.0 * sin(x * 0.045)
	var riv := smoothstep(7.0, 2.0, absf(z - rz)) * smoothstep(52.0, 40.0, x)
	if riv > 0.0:
		h = lerpf(h, -1.1, riv)
	# pond
	var pd := Vector2(x + 42.0, z + 22.0).length()
	if pd < 13.0:
		h = lerpf(h, -1.2, smoothstep(13.0, 5.0, pd))
	# gentle flat start area
	var sd := Vector2(x, z).length()
	if sd < 30.0:
		h = lerpf(h, 2.6, smoothstep(30.0, 10.0, sd))
	# mountain rim
	var m := maxf(absf(x), absf(z))
	if m > 100.0:
		h += smoothstep(100.0, 116.0, m) * 30.0
	return h


func _compute_landmark_flatten() -> void:
	lm_flat.clear()
	for id in Data.landmarks:
		var p: Vector2 = Data.landmarks[id]["pos"]
		var r := 15.0 if id == "hollow" else 8.0
		lm_flat.append([p.x, p.y, _raw_height(p.x, p.y), r])


func height_at(x: float, z: float) -> float:
	var h := _raw_height(x, z)
	for lf in lm_flat:
		var d := Vector2(x - lf[0], z - lf[1]).length()
		if d < lf[3] + 5.0:
			h = lerpf(h, lf[2], smoothstep(lf[3] + 5.0, lf[3] - 2.0, d))
	return h


func _build_terrain() -> void:
	var n := GRID + 1
	var half := GRID * CELL * 0.5
	var hs := PackedFloat32Array()
	hs.resize(n * n)
	for iz in n:
		for ix in n:
			hs[iz * n + ix] = height_at(-half + ix * CELL, -half + iz * CELL)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	verts.resize(n * n)
	norms.resize(n * n)
	cols.resize(n * n)
	var cn := FastNoiseLite.new()
	cn.seed = 5
	cn.frequency = 0.08
	for iz in n:
		for ix in n:
			var x := -half + ix * CELL
			var z := -half + iz * CELL
			var h := hs[iz * n + ix]
			var hl := hs[iz * n + maxi(ix - 1, 0)]
			var hr := hs[iz * n + mini(ix + 1, n - 1)]
			var hd := hs[maxi(iz - 1, 0) * n + ix]
			var hu := hs[mini(iz + 1, n - 1) * n + ix]
			var nrm := Vector3(hl - hr, 2.0 * CELL, hd - hu).normalized()
			verts[iz * n + ix] = Vector3(x, h, z)
			norms[iz * n + ix] = nrm
			cols[iz * n + ix] = _terrain_color(x, z, h, nrm, cn.get_noise_2d(x, z))
	var idx := PackedInt32Array()
	idx.resize(GRID * GRID * 6)
	var k := 0
	for iz in GRID:
		for ix in GRID:
			var a := iz * n + ix
			var b := a + 1
			var c := a + n
			var d := c + 1
			idx[k] = a
			idx[k + 1] = b
			idx[k + 2] = c
			idx[k + 3] = b
			idx[k + 4] = d
			idx[k + 5] = c
			k += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 1.0
	mesh.surface_set_material(0, m)
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = mesh
	add_child(mi)
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	body.collision_layer = 1
	body.collision_mask = 0
	# Collision is built straight from the height data (not from the render mesh) so it never
	# depends on the rendering backend.
	var faces := PackedVector3Array()
	faces.resize(idx.size())
	for fi in idx.size():
		faces[fi] = verts[idx[fi]]
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	add_child(body)


func _terrain_color(x: float, z: float, h: float, nrm: Vector3, cn: float) -> Color:
	var grass := Color(0.36, 0.62, 0.28).lerp(Color(0.5, 0.72, 0.3), cn * 0.5 + 0.5)
	var ember := Color(0.6, 0.3, 0.2).lerp(Color(0.78, 0.42, 0.22), cn * 0.5 + 0.5)
	var e := smoothstep(44.0, 58.0, x)
	var c := grass.lerp(ember, e)
	if h > 6.5 and e > 0.2:
		c = c.lerp(Color(0.25, 0.2, 0.2), clampf((h - 6.5) / 6.0, 0.0, 0.8))
	if h < WATER_Y + 0.35:
		c = c.lerp(Color(0.78, 0.72, 0.52), clampf((WATER_Y + 0.35 - h) / 0.5, 0.0, 1.0))
	if nrm.y < 0.8:
		c = c.lerp(Color(0.5, 0.48, 0.46), clampf((0.8 - nrm.y) * 3.0, 0.0, 0.85))
	if maxf(absf(x), absf(z)) > 100.0:
		c = c.lerp(Color(0.45, 0.45, 0.5), 0.8)
	return c


func _build_water() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(250, 250)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.2, 0.5, 0.75, 0.6)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.1
	m.metallic = 0.1
	pm.material = m
	var mi := MeshInstance3D.new()
	mi.name = "Water"
	mi.mesh = pm
	mi.position.y = WATER_Y
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func normal_slope(x: float, z: float) -> float:
	var hx := height_at(x + 0.7, z) - height_at(x - 0.7, z)
	var hz := height_at(x, z + 0.7) - height_at(x, z - 0.7)
	return sqrt(hx * hx + hz * hz) / 1.4


# ------------------------------------------------------------ environment / time
func _build_environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_density = 0.006
	env.fog_light_color = Color(0.7, 0.8, 0.9)
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 45.0
	sun.light_energy = 1.1
	add_child(sun)


func is_night() -> bool:
	return sin(time_of_day * TAU) < -0.05


func _update_environment() -> void:
	var elev := sin(time_of_day * TAU)
	var day_f := smoothstep(-0.1, 0.25, elev)
	var dusk_f := clampf(1.0 - absf(elev) / 0.35, 0.0, 1.0)
	var top := Color(0.02, 0.04, 0.12).lerp(Color(0.25, 0.5, 0.9), day_f)
	var hor := Color(0.05, 0.07, 0.16).lerp(Color(0.65, 0.8, 0.95), day_f).lerp(Color(1.0, 0.55, 0.3), dusk_f * 0.55)
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = hor
	sky_mat.ground_horizon_color = hor
	sky_mat.ground_bottom_color = top.darkened(0.4)
	env.fog_light_color = hor
	env.ambient_light_energy = lerpf(0.4, 0.85, day_f)
	sun.light_energy = lerpf(0.12, 1.15, day_f)
	sun.light_color = Color(0.55, 0.65, 1.0).lerp(Color(1.0, 0.95, 0.85), day_f).lerp(Color(1.0, 0.7, 0.45), dusk_f * 0.5)
	sun.rotation_degrees = Vector3(-lerpf(14.0, 62.0, clampf(elev, 0.0, 1.0)), time_of_day * 360.0, 0.0)


func comfort_info(pos: Vector3) -> Dictionary:
	var target := 70.0
	var kind := "ok"
	if Data.region_at(pos.x, pos.z) == "ember":
		if is_night():
			target = 58.0
		else:
			target = 20.0 if pos.x > 80.0 else 32.0
			kind = "hot"
	elif is_night():
		target = 42.0
		kind = "cold"
	if kind == "cold" and build_manager != null and build_manager.has_station_near("campfire", pos, 9.0):
		target = 75.0
		kind = "ok"
	return {"target": target, "kind": kind}


func apply_quality() -> void:
	var q: int = int(Game.settings["quality"])
	if sun == null:
		return
	sun.shadow_enabled = q >= 1
	sun.directional_shadow_max_distance = 35.0 if q == 1 else 70.0
	var vp := get_viewport()
	if vp:
		vp.msaa_3d = Viewport.MSAA_2X if q >= 2 else Viewport.MSAA_DISABLED
	env.fog_enabled = true
	for c in get_children():
		if c.name.begins_with("Decor"):
			for ch in c.get_children():
				if ch is GeometryInstance3D:
					ch.visibility_range_end = [45.0, 75.0, 110.0][clampi(q, 0, 2)]


# ------------------------------------------------------------ decor (chunked MultiMeshes = real distance culling)
func _build_decor() -> void:
	var holder := Node3D.new()
	holder.name = "Decor"
	add_child(holder)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var grass_mesh := CylinderMesh.new()
	grass_mesh.top_radius = 0.0
	grass_mesh.bottom_radius = 0.1
	grass_mesh.height = 0.6
	grass_mesh.radial_segments = 4
	grass_mesh.rings = 1
	var flower_mesh := SphereMesh.new()
	flower_mesh.radius = 0.1
	flower_mesh.height = 0.2
	flower_mesh.radial_segments = 6
	flower_mesh.rings = 3
	var ember_mesh := BoxMesh.new()
	ember_mesh.size = Vector3(0.35, 0.35, 0.35)
	var vmat := StandardMaterial3D.new()
	vmat.vertex_color_use_as_albedo = true
	vmat.roughness = 1.0
	var emat := StandardMaterial3D.new()
	emat.albedo_color = Color(0.25, 0.15, 0.12)
	emat.emission_enabled = true
	emat.emission = Color(1.0, 0.4, 0.12)
	emat.emission_energy_multiplier = 1.6
	var fl_cols := [Color(1, 1, 1), Color(1, 0.9, 0.3), Color(1, 0.55, 0.75), Color(0.7, 0.55, 1.0)]
	var sets := {"grass": {"mesh": grass_mesh, "mat": vmat, "n": 2600, "chunks": {}},
		"flower": {"mesh": flower_mesh, "mat": vmat, "n": 420, "chunks": {}},
		"ember": {"mesh": ember_mesh, "mat": emat, "n": 160, "chunks": {}}}
	for key in sets:
		var placed := 0
		var tries := 0
		while placed < int(sets[key]["n"]) and tries < int(sets[key]["n"]) * 4:
			tries += 1
			var x := rng.randf_range(-98.0, 98.0)
			var z := rng.randf_range(-98.0, 98.0)
			var is_ember := x > 52.0
			if key == "ember" and not is_ember:
				continue
			if key != "ember" and is_ember:
				continue
			var h := height_at(x, z)
			if h < WATER_Y + 0.3 or normal_slope(x, z) > 0.55:
				continue
			var s := rng.randf_range(0.7, 1.5) if key == "grass" else (1.0 if key == "flower" else rng.randf_range(0.6, 1.4))
			var tf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(x, h + (0.28 * s if key == "grass" else (0.35 if key == "flower" else 0.1)), z))
			var col := Color(0.3, 0.55, 0.25).lerp(Color(0.55, 0.78, 0.3), rng.randf())
			if key == "flower":
				col = fl_cols[rng.randi() % fl_cols.size()]
				tf.origin.y = h + 0.6
			var ck := Vector2i(floori(x / 50.0), floori(z / 50.0))
			if not sets[key]["chunks"].has(ck):
				sets[key]["chunks"][ck] = []
			sets[key]["chunks"][ck].append([tf, col])
			placed += 1
	for key in sets:
		for ck in sets[key]["chunks"]:
			var list: Array = sets[key]["chunks"][ck]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = sets[key]["mesh"]
			mm.instance_count = list.size()
			for i in list.size():
				mm.set_instance_transform(i, list[i][0])
				mm.set_instance_color(i, list[i][1])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = sets[key]["mat"]
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.visibility_range_end = 75.0
			holder.add_child(mmi)


# ------------------------------------------------------------ obstacles (for creature steering and placement checks)
func _ob_bucket(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / 3.0), floori(p.y / 3.0))


func register_obstacle(node: Node, p: Vector2, r: float) -> void:
	var b := _ob_bucket(p)
	if not obstacle_hash.has(b):
		obstacle_hash[b] = []
	obstacle_hash[b].append({"p": p, "r": r, "node": node, "active": true})


func set_obstacle_active(node: Node, active: bool) -> void:
	var p := Vector2(node.global_position.x, node.global_position.z)
	var b := _ob_bucket(p)
	if obstacle_hash.has(b):
		for e in obstacle_hash[b]:
			if e["node"] == node:
				e["active"] = active


func obstacle_overlap(center: Vector3, r: float) -> bool:
	var p := Vector2(center.x, center.z)
	var b := _ob_bucket(p)
	var reach := int(ceil((r + 2.5) / 3.0))
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var k := Vector2i(b.x + dx, b.y + dz)
			if obstacle_hash.has(k):
				for e in obstacle_hash[k]:
					if e["active"] and p.distance_to(e["p"]) < r + float(e["r"]):
						return true
	return false


func can_walk(p: Vector3, water_ok: bool) -> bool:
	if absf(p.x) > 108.0 or absf(p.z) > 108.0:
		return false
	var h := height_at(p.x, p.z)
	if water_ok:
		if h < WATER_Y - 1.7:
			return false
	elif h < WATER_Y - 0.25:
		return false
	if normal_slope(p.x, p.z) > 0.9:
		return false
	if obstacle_overlap(p, 0.35):
		return false
	if build_manager != null and build_manager.blocks(p, true):
		return false
	return true


# ------------------------------------------------------------ landmarks
func _build_landmarks() -> void:
	for id in Data.landmarks:
		var lm: Dictionary = Data.landmarks[id]
		var p: Vector2 = lm["pos"]
		var node: Node3D = Landmark.new()
		node.name = "LM_" + id
		add_child(node)
		node.setup(self, id, Vector3(p.x, height_at(p.x, p.y), p.y))
		landmark_nodes[id] = node
		var r := 1.5 if id in ["old_marker", "shrine", "watchtower"] else (0.0 if id in ["hollow", "camp"] else 1.0)
		if r > 0.0:
			register_obstacle(node, p, r + 1.0)
		if id == "camp":
			register_obstacle(node, p, 2.2)


func marker_pos(marker: String) -> Variant:
	if marker == "":
		return null
	if marker == "starter_mossbun":
		for c in wild_creatures:
			if is_instance_valid(c) and c.spawn_id == "w_start":
				return c.global_position
		return Vector3(9, 0, 6)
	if landmark_nodes.has(marker):
		return landmark_nodes[marker].global_position
	return null


# ------------------------------------------------------------ resources
func _slope_ok(x: float, z: float, max_slope: float) -> bool:
	return normal_slope(x, z) <= max_slope


func _populate_resources() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var idx := 0
	var plan: Array = []
	# guaranteed starter cluster around camp (meadow, 8-26 m from spawn)
	for kv in [["tree", 11], ["rock", 6], ["fiber", 7], ["berry", 6], ["herb", 3]]:
		for i in kv[1]:
			plan.append([kv[0], "near", 8.0, 26.0])
	# the rest of the meadow
	for kv in [["tree", 55], ["rock", 16], ["fiber", 14], ["berry", 10], ["herb", 9]]:
		for i in kv[1]:
			plan.append([kv[0], "meadow", 0.0, 0.0])
	# Ember Highlands
	for kv in [["tree", 16], ["rock", 20], ["ore", 16], ["crystal", 7], ["shard", 12], ["herb", 3]]:
		for i in kv[1]:
			plan.append([kv[0], "ember", 0.0, 0.0])
	for entry in plan:
		var kind: String = entry[0]
		var pos := Vector2.ZERO
		var ok := false
		for attempt in 60:
			match entry[1]:
				"near":
					var a := rng.randf() * TAU
					var r := rng.randf_range(entry[2], entry[3])
					pos = Vector2(cos(a) * r, sin(a) * r)
				"meadow":
					pos = Vector2(rng.randf_range(-100.0, 46.0), rng.randf_range(-100.0, 100.0))
				_:
					pos = Vector2(rng.randf_range(54.0, 100.0), rng.randf_range(-100.0, 100.0))
			if _resource_spot_ok(pos, kind):
				ok = true
				break
		if not ok:
			continue
		var h := height_at(pos.x, pos.y)
		var node: Node3D = ResourceNode.new()
		var sc := rng.randf_range(0.85, 1.25) if kind in ["tree", "rock"] else rng.randf_range(0.9, 1.15)
		node.name = "R%d" % idx
		resources_root.add_child(node)
		node.setup(self, "r%d" % idx, kind, Vector3(pos.x, h, pos.y), pos.x >= Data.EMBER_START_X, rng.randf() * TAU, sc)
		register_obstacle(node, pos, ResourceNode.KINDS[kind]["radius"] * sc * 0.9)
		resource_nodes.append(node)
		resource_by_id[node.rid] = node
		idx += 1


func _resource_spot_ok(p: Vector2, kind: String) -> bool:
	var h := height_at(p.x, p.y)
	if h < WATER_Y + 0.4:
		return false
	var max_slope := 0.75 if kind in ["rock", "ore", "crystal", "shard"] else 0.5
	if not _slope_ok(p.x, p.y, max_slope):
		return false
	if p.length() < 6.0:
		return false
	if p.distance_to(Vector2(9, 6)) < 4.0:
		return false  # keep the first Wildling's meadow clear
	for id in Data.landmarks:
		var lp: Vector2 = Data.landmarks[id]["pos"]
		var clear := 16.0 if id == "hollow" else 6.0
		if p.distance_to(lp) < clear:
			return false
	if obstacle_overlap(Vector3(p.x, 0, p.y), 2.6):
		return false
	return true


func register_depleted(node: Node) -> void:
	if not depleted_nodes.has(node):
		depleted_nodes.append(node)


func reveal_resources(pos: Vector3, radius: float, secs: float) -> int:
	var n := 0
	for r in resource_nodes:
		if not r.depleted and r.global_position.distance_to(pos) <= radius:
			r.marker.visible = true
			revealed[r] = world_time + secs
			n += 1
	spawn_burst(pos + Vector3(0, 1, 0), Color(1, 0.95, 0.4), 12)
	return n


func tend_plots(pos: Vector3, radius: float) -> int:
	var n := 0
	for id in build_manager.structures:
		var s: Node = build_manager.structures[id]
		if s.type == "plot" and s.global_position.distance_to(pos) <= radius and str(s.state.get("crop", "")) != "":
			s.water_plot(300.0)
			n += 1
	if n > 0:
		spawn_burst(pos + Vector3(0, 1, 0), Color(0.5, 0.8, 1.0), 10)
	return n


func plot_growth_mult() -> float:
	return 1.5 if Game.active_creature().get("species", "") == "snailbell" else 1.0


func dig_for_treasure(pos: Vector3) -> void:
	var ember := Data.region_at(pos.x, pos.z) == "ember"
	var table: Array = [["ore", 45], ["crystal", 25], ["ember_shard", 30]] if ember else [["stone", 40], ["ore", 30], ["fiber", 20], ["crystal", 10]]
	var roll := randi() % 100
	var acc := 0
	var item := "stone"
	for e in table:
		acc += int(e[1])
		if roll < acc:
			item = e[0]
			break
	var fwd := Vector3(-sin(player.facing_yaw), 0, -cos(player.facing_yaw)) * 2.0
	var amt := 1 if item in ["crystal", "ember_shard"] else 2
	spawn_pickup(item, amt, pos + fwd)
	Game.toast("Your companion unearthed %d %s!" % [amt, Data.item_name(item)], "discover")
	spawn_burst(pos + fwd + Vector3(0, 0.4, 0), Color(0.7, 0.55, 0.35), 14)


# ------------------------------------------------------------ creatures
func _build_spawn_table() -> void:
	spawn_table.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	spawn_table.append({"id": "w_start", "species": "mossbun", "pos": Vector2(9, 6)})
	var plan := [["mossbun", 3, "meadow"], ["bramblehog", 3, "meadow"], ["glimmerwing", 2, "high"], ["lumifox", 2, "meadow"],
		["pondling", 3, "water"], ["snailbell", 3, "meadow"], ["thistlefinch", 3, "meadow"], ["cinderstag", 3, "ember"]]
	for pe in plan:
		for i in pe[1]:
			var p := Vector2.ZERO
			var found := false
			for attempt in 120:
				match pe[2]:
					"ember":
						p = Vector2(rng.randf_range(60.0, 100.0), rng.randf_range(-90.0, 90.0))
					"water":
						var a := rng.randf() * TAU
						var r := rng.randf_range(11.0, 16.0)
						p = Vector2(-42.0 + cos(a) * r, -22.0 + sin(a) * r)
					"high":
						p = Vector2(rng.randf_range(-95.0, 44.0), rng.randf_range(-95.0, 95.0))
					_:
						p = Vector2(rng.randf_range(-95.0, 44.0), rng.randf_range(-95.0, 95.0))
				var h := height_at(p.x, p.y)
				if h < WATER_Y + 0.25 or not _slope_ok(p.x, p.y, 0.5) or p.length() < 14.0:
					continue
				if pe[2] == "high" and h < 4.2:
					continue
				if obstacle_overlap(Vector3(p.x, 0, p.y), 1.0):
					continue
				found = true
				break
			if found:
				spawn_table.append({"id": "w_%s_%d" % [pe[0], i], "species": pe[0], "pos": p})
	var hp: Vector2 = Data.landmarks["hollow"]["pos"]
	spawn_table.append({"id": "boss_hollow", "species": "rustmaw", "pos": hp})


func _spawn_wild_creatures() -> void:
	for c in wild_creatures:
		if is_instance_valid(c):
			c.queue_free()
	wild_creatures.clear()
	for e in spawn_table:
		if Game.wild_taken.has(e["id"]):
			continue
		_spawn_one(e)


func _spawn_one(e: Dictionary) -> void:
	var c: Node3D = Creature.new()
	c.name = e["id"]
	creatures_root.add_child(c)
	c.setup(self, e["species"], Vector3(e["pos"].x, 0, e["pos"].y), e["id"])
	wild_creatures.append(c)
	if c.hostile:
		hostile_boss = c


func befriend(c: Node) -> void:
	var rec := Game.add_creature(c.species)
	if rec.is_empty():
		return
	Game.wild_taken[c.spawn_id] = 900.0
	Game.discover_species(c.species)
	Quests.notify_event("befriend", c.species, 1)
	Game.add_xp(25, "befriend")
	Game.toast("%s joined you!" % Data.creatures[c.species]["name"], "quest")
	Sfx.play("discover")
	Sfx.play_voice(c.species)
	spawn_burst(c.global_position + Vector3(0, 1.2, 0), Color(1, 0.8, 0.4), 18)
	wild_creatures.erase(c)
	c.queue_free()
	player.celebrate()
	save_now(false)


func on_hostile_defeated(c: Node) -> void:
	var p: Vector3 = c.global_position
	spawn_pickup("ember_shard", 2, p + Vector3(1.5, 0, 0))
	spawn_pickup("crystal", 1, p + Vector3(-1.5, 0, 0))
	spawn_pickup("ore", 3, p + Vector3(0, 0, 1.5))
	Game.add_xp(150, "boss")
	Game.wild_taken[c.spawn_id] = 600.0
	Quests.notify_event("defeat", c.species, 1)
	Game.toast("You defeated the %s!" % c.def["name"], "quest")
	Sfx.play("levelup")
	spawn_burst(p + Vector3(0, 2, 0), Color(1, 0.7, 0.2), 30)
	wild_creatures.erase(c)
	if hostile_boss == c:
		hostile_boss = null
	player.celebrate()
	Sfx.play_music("ember")
	save_now(false)


func nearest_hostile(pos: Vector3, radius: float) -> Node:
	var best: Node = null
	var bd := radius
	for h in get_tree().get_nodes_in_group("hostile"):
		if not is_instance_valid(h):
			continue
		var d: float = h.global_position.distance_to(pos)
		if d < bd and h.engaged:
			bd = d
			best = h
	return best


func engaged_boss() -> Node:
	for h in get_tree().get_nodes_in_group("hostile"):
		if is_instance_valid(h) and h.engaged:
			return h
	return null


func _on_companion_changed() -> void:
	_sync_companion()


func _sync_companion() -> void:
	var uid := Game.active_uid
	if uid == _companion_uid_spawned and (companion_node != null or uid == ""):
		return
	_companion_uid_spawned = uid
	if companion_node != null and is_instance_valid(companion_node):
		companion_node.queue_free()
	companion_node = null
	var c := Game.active_creature()
	if c.is_empty() or player == null:
		return
	var pp: Vector3 = player.global_position
	var node: Node3D = Creature.new()
	node.name = "Companion"
	creatures_root.add_child(node)
	node.setup(self, c["species"], pp + Vector3(1.5, 0, 1.5), "", true)
	companion_node = node


# ------------------------------------------------------------ pickups & effects
func spawn_pickup_near_player(id: String, n: int) -> void:
	var a := randf() * TAU
	spawn_pickup(id, n, player.global_position + Vector3(cos(a) * 1.6, 0, sin(a) * 1.6))


func spawn_pickup(id: String, n: int, pos: Vector3) -> void:
	if not Data.items.has(id) or n <= 0:
		return
	if pickups.size() >= 60:
		var old: Dictionary = pickups.pop_front()
		if is_instance_valid(old["node"]):
			old["node"].queue_free()
	var node := Node3D.new()
	var col: Color = Data.get_item(id)["color"]
	CM.part(node, "sphere", Vector3(0.38, 0.38, 0.38), col, Vector3(0, 0, 0), Vector3.ZERO, 0.8)
	CM.part(node, "box", Vector3(0.22, 0.22, 0.22), col.lightened(0.3), Vector3(0, 0, 0), Vector3(45, 45, 0), 1.2)
	node.position = Vector3(pos.x, height_at(pos.x, pos.z) + 0.7, pos.z)
	pickups_root.add_child(node)
	pickups.append({"id": id, "n": n, "node": node, "t": randf() * 6.0})


func float_text(pos: Vector3, text: String, color: Color = Color(1, 1, 1)) -> void:
	if _float_count >= 16:
		return
	_float_count += 1
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 48
	l.pixel_size = 0.01
	l.outline_size = 14
	l.modulate = color
	l.position = pos
	fx_root.add_child(l)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", pos.y + 1.3, 1.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.0).set_delay(0.4)
	tw.chain().tween_callback(func():
		_float_count -= 1
		l.queue_free())


func spawn_burst(pos: Vector3, color: Color, amount: int) -> void:
	var q: int = int(Game.settings["quality"])
	if _burst_count >= 12 or (q == 0 and amount > 8):
		return
	_burst_count += 1
	if _burst_mesh == null:
		_burst_mesh = SphereMesh.new()
		_burst_mesh.radius = 0.07
		_burst_mesh.height = 0.14
		_burst_mesh.radial_segments = 4
		_burst_mesh.rings = 2
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = maxi(amount if q > 0 else amount / 2, 3)
	p.lifetime = 0.7
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.5
	p.gravity = Vector3(0, -7, 0)
	p.mesh = _burst_mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p.material_override = m
	p.position = pos
	fx_root.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(func():
		_burst_count -= 1
		if is_instance_valid(p):
			p.queue_free())


func shake_camera(amount: float) -> void:
	if player:
		player.shake(amount)


# ------------------------------------------------------------ per-frame logic
func _process(delta: float) -> void:
	world_time += delta
	time_of_day = fposmod(time_of_day + delta / DAY_LENGTH, 1.0)
	_env_t -= delta
	if _env_t <= 0.0:
		_env_t = 0.5
		_update_environment()
	_tick1 += delta
	if _tick1 >= 1.0:
		_slow_tick(_tick1)
		_tick1 = 0.0
	_tick_half += delta
	if _tick_half >= 0.5:
		_tick_half = 0.0
		_stream_tick()
		_discovery_tick()
	_pickup_tick(delta)
	if Game.state == Game.State.BUILDING and build_manager.active:
		build_manager.update_preview(player.global_position, player.cam_forward(), player.cam_pitch)
	_autosave_t += delta
	if _autosave_t >= AUTOSAVE_SECONDS and Game.is_playing():
		_autosave_t = 0.0
		save_now(true)


func _pickup_tick(delta: float) -> void:
	var ppos := player.global_position
	var collect := Game.state == Game.State.PLAY
	var i := pickups.size() - 1
	while i >= 0:
		var pk: Dictionary = pickups[i]
		var node: Node3D = pk["node"]
		if not is_instance_valid(node):
			pickups.remove_at(i)
			i -= 1
			continue
		pk["t"] += delta
		node.position.y += sin(pk["t"] * 3.0) * 0.004
		node.rotation.y += delta * 1.5
		if collect and node.global_position.distance_to(ppos + Vector3(0, 0.8, 0)) < 1.9:
			var left: int = Inv.add(pk["id"], pk["n"])
			if left < int(pk["n"]):
				Sfx.play("pickup")
				float_text(node.global_position + Vector3(0, 0.6, 0), "+%d %s" % [int(pk["n"]) - left, Data.item_name(pk["id"])])
				Quests.notify_event("gather", pk["id"], int(pk["n"]) - left)
			if left <= 0:
				node.queue_free()
				pickups.remove_at(i)
			else:
				pk["n"] = left
				if pk.get("warned", 0.0) < world_time - 5.0:
					pk["warned"] = world_time
					Game.toast("Pack full!", "warn")
		i -= 1


func _slow_tick(dt: float) -> void:
	# resource respawns
	var i := depleted_nodes.size() - 1
	while i >= 0:
		var n: Node = depleted_nodes[i]
		if not is_instance_valid(n):
			depleted_nodes.remove_at(i)
		else:
			n.respawn_left -= dt
			if n.respawn_left <= 0.0:
				n.respawn()
				depleted_nodes.remove_at(i)
		i -= 1
	# reveal markers expire
	for r in revealed.keys():
		if not is_instance_valid(r) or revealed[r] <= world_time:
			if is_instance_valid(r):
				r.marker.visible = false
			revealed.erase(r)
	# wild creature respawn timers
	for k in Game.wild_taken.keys():
		Game.wild_taken[k] = float(Game.wild_taken[k]) - dt
		if Game.wild_taken[k] <= 0.0:
			Game.wild_taken.erase(k)
			for e in spawn_table:
				if e["id"] == k:
					_spawn_one(e)
	# farming + creature production
	var mult := plot_growth_mult()
	for id in build_manager.structures:
		var s: Node = build_manager.structures[id]
		if s.type == "plot" or s.type == "rest":
			s.tick(dt, mult)
	# cooldown of heat etc handled by player; refresh HUD cheaply
	Game.stats_changed.emit()


func _stream_tick() -> void:
	var ppos := player.global_position
	for r in resource_nodes:
		r.visible = r.global_position.distance_squared_to(ppos) < 110.0 * 110.0
	for c in wild_creatures:
		if not is_instance_valid(c):
			continue
		var far: bool = c.global_position.distance_squared_to(ppos) > 90.0 * 90.0 and not c.engaged
		c.visible = not far
		c.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT
	for id in build_manager.structures:
		var s: Node = build_manager.structures[id]
		s.visible = s.global_position.distance_squared_to(ppos) < 120.0 * 120.0
	wild_creatures = wild_creatures.filter(func(c): return is_instance_valid(c))
	# keep the companion in sync after load / release
	if Game.active_uid != _companion_uid_spawned:
		_sync_companion()
	elif companion_node != null and not is_instance_valid(companion_node):
		_companion_uid_spawned = "<none>"
		_sync_companion()


func _discovery_tick() -> void:
	var p := player.global_position
	Game.reveal_area(p.x, p.z, 16.0)
	var region := Data.region_at(p.x, p.z)
	if region != current_region:
		current_region = region
		Game.visit_region(region)
		if engaged_boss() == null:
			Sfx.play_music("ember" if region == "ember" else "explore")
	for id in Data.landmarks:
		if Game.found_landmarks.has(id):
			continue
		var lp: Vector2 = Data.landmarks[id]["pos"]
		if Vector2(p.x - lp.x, p.z - lp.y).length() < 10.0:
			Game.visit_landmark(id)
			Sfx.play("discover")


func station_nearby(station: String) -> bool:
	if station == "":
		return true
	return build_manager.has_station_near(station, player.global_position, 8.0)


# ------------------------------------------------------------ defeat / recovery
func on_player_defeated() -> void:
	Sfx.play("hurt")
	Game.push_state(Game.State.DEFEAT)


func recover_player() -> void:
	Game.health = Game.max_health * 0.5
	Game.hunger = maxf(Game.hunger, 40.0)
	Game.stamina = 100.0
	Game.comfort = 70.0
	Game.heat_resist = 0.0
	player.invuln = 2.0
	var camp: Vector2 = Data.landmarks["camp"]["pos"]
	player.place_at(Vector3(camp.x + 3.0, height_at(camp.x + 3.0, camp.y) + 1.0, camp.y))
	for h in get_tree().get_nodes_in_group("hostile"):
		if is_instance_valid(h):
			h._reset_encounter()
	if companion_node and is_instance_valid(companion_node):
		companion_node.global_position = player.global_position + Vector3(2, 0, 0)
	Game.pop_state()
	Game.stats_changed.emit()
	save_now(true)


func rest_at_campfire() -> void:
	player.rest_for(3.0)
	Game.heal_player(35.0)
	Game.stamina = 100.0
	Game.comfort = maxf(Game.comfort, 72.0)
	Game.toast("You rest by the fire and feel refreshed.", "info")


# ------------------------------------------------------------ back button / lifecycle
func on_back_requested() -> void:
	if hud:
		hud.handle_back()


func on_app_paused() -> void:
	if hud and Game.state == Game.State.PLAY:
		hud.open_pause()


func _on_state_changed(_s: int) -> void:
	pass


# ------------------------------------------------------------ save / load
func serialize_world() -> Dictionary:
	var dep := {}
	for n in depleted_nodes:
		if is_instance_valid(n):
			dep[n.rid] = n.respawn_left
	var pk: Array = []
	for p in pickups:
		if is_instance_valid(p["node"]):
			var q: Vector3 = p["node"].position
			pk.append({"id": p["id"], "n": p["n"], "pos": [q.x, q.y, q.z]})
	var cores: Array = []
	if landmark_nodes.has("shrine") and landmark_nodes["shrine"].core_restored:
		cores.append("shrine")
	return {
		"player": {"pos": [player.global_position.x, player.global_position.y, player.global_position.z],
			"yaw": player.cam_yaw_target, "pitch": player.cam_pitch_target},
		"time_of_day": time_of_day, "world_time": world_time, "saved_unix": Time.get_unix_time_from_system(),
		"depleted": dep, "pickups": pk, "cores": cores,
		"structures": build_manager.serialize(),
	}


func save_now(silent: bool = true) -> bool:
	if no_autosave or player == null:
		return false
	var payload := {"game": Game.serialize(), "inventory": Inv.serialize(), "quests": Quests.serialize(),
		"world": serialize_world()}
	var ok := Save.write_game(payload)
	if not ok:
		Game.toast("Could not save! Check device storage.", "warn")
	elif not silent:
		Game.toast("Game saved.", "info")
	return ok


func manual_save() -> void:
	if save_now(true):
		Game.toast("Game saved.", "info")
		Sfx.play("quest")
		Quests.notify_event("save", "", 1)


func _load_from_disk() -> bool:
	var res: Dictionary = Save.load_game()
	if not res["ok"]:
		Game.menu_message = str(res["message"])
		return false
	var d: Dictionary = res["data"]
	Game.deserialize(d["game"])
	Inv.deserialize(d["inventory"])
	Quests.deserialize(d["quests"])
	var w: Dictionary = d["world"]
	time_of_day = clampf(float(w.get("time_of_day", 0.06)), 0.0, 1.0)
	world_time = maxf(float(w.get("world_time", 0.0)), 0.0)
	# structures first so interactions work immediately
	for sd in w.get("structures", []):
		if typeof(sd) == TYPE_DICTIONARY and Data.buildings.has(str(sd.get("type", ""))):
			var pa: Array = sd.get("pos", [0, 0, 0])
			if pa.size() == 3:
				build_manager.place_structure(str(sd["type"]), Vector3(float(pa[0]), float(pa[1]), float(pa[2])),
					float(sd.get("rot", 0.0)), sd.get("state", {}), str(sd.get("id", "")))
	var dep: Dictionary = w.get("depleted", {})
	for rid in dep:
		if resource_by_id.has(rid):
			var left := maxf(float(dep[rid]), 0.0)
			resource_by_id[rid].restore_depleted(left)
			register_depleted(resource_by_id[rid])
	for pk in w.get("pickups", []):
		var pa2: Array = pk.get("pos", [0, 0, 0])
		if pa2.size() == 3:
			spawn_pickup(str(pk.get("id", "")), int(pk.get("n", 1)), Vector3(float(pa2[0]), 0, float(pa2[2])))
	for core in w.get("cores", []):
		if landmark_nodes.has(core):
			landmark_nodes[core].restore_core(false)
	# offline catch-up is deliberately small and clamped (guards against clock changes)
	var elapsed := clampf(Time.get_unix_time_from_system() - float(w.get("saved_unix", 0.0)), 0.0, 1800.0)
	if elapsed > 0.0:
		for n in depleted_nodes:
			if is_instance_valid(n):
				n.respawn_left -= elapsed
		for k in Game.wild_taken.keys():
			Game.wild_taken[k] = float(Game.wild_taken[k]) - elapsed
			if Game.wild_taken[k] <= 0.0:
				Game.wild_taken.erase(k)
		for id in build_manager.structures:
			var s: Node = build_manager.structures[id]
			if s.type == "plot" or s.type == "rest":
				s.tick(elapsed * 0.5, 1.0)
	var pp: Dictionary = w.get("player", {})
	var pos: Array = pp.get("pos", [0.0, 5.0, 0.0])
	if pos.size() == 3:
		var px := clampf(float(pos[0]), -100.0, 100.0)
		var pz := clampf(float(pos[2]), -100.0, 100.0)
		player.place_at(Vector3(px, height_at(px, pz) + 1.0, pz))
	player.cam_yaw = float(pp.get("yaw", -PI * 0.5))
	player.cam_yaw_target = player.cam_yaw
	player.cam_pitch_target = clampf(float(pp.get("pitch", 0.35)), -0.15, 1.25)
	player.cam_pitch = player.cam_pitch_target
	if res["restored_backup"]:
		Game.toast(str(res["message"]), "warn")
	else:
		Game.toast("Game loaded.", "info")
	return true
