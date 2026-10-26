extends Node3D
## The game world: terrain, sky, decor, resources, player, enemies and all runtime systems.

const WG = preload("res://scripts/world/world_gen.gd")
const DW = preload("res://scripts/core/data_world.gd")
const Terrain = preload("res://scripts/world/terrain.gd")
const SkyEnv = preload("res://scripts/world/sky_env.gd")
const Decor = preload("res://scripts/world/decor.gd")
const ResourceNode = preload("res://scripts/world/resource_node.gd")
const Pickup = preload("res://scripts/world/pickup.gd")
const PlayerScript = preload("res://scripts/player/player.gd")
const BuildManager = preload("res://scripts/building/build_manager.gd")
const Spawner = preload("res://scripts/world/spawner.gd")
const Projectile = preload("res://scripts/enemies/projectile.gd")

signal loading_progress(f: float, text: String)
signal loaded

const WORLD_SEED := 1337
const HASH_CELL := 8.0

var terrain: Node3D
var sky: Node3D
var decor: Node3D
var player: CharacterBody3D
var touch: Control = null
var hud: Node = null

var player_region: String = "coast"
var resources: Array = []
var _hash: Dictionary = {}                 # Vector2i -> Array of interactables
var _active_col: Dictionary = {}           # node -> true
var enemies: Array = []
var animals: Array = []
var spawner: Node = null
var sites = null
var death_node: Node = null
var _site_acc: float = 0.0
var _dmg_labels: Array = []
var _dmg_i: int = 0
var boss_nodes: Array = []
var projectiles: Array = []
var _burst_pool: Array = []
var _burst_i: int = 0
var _tick_acc: float = 0.0
var _col_acc: float = 0.0
var _last_player_pos: Vector3
var cutscene: bool = false
var flash: ColorRect = null
var ready_done: bool = false
var fog_target: float = 0.0016
var _rng := RandomNumberGenerator.new()
var warm_sources: Array = []               # [Vector3 pos, radius, strength]
var metal_zones: Array = []                # [Vector2 pos, radius]
var builder: Node = null
var _shelter_acc: float = 0.0
var sleeping: bool = false


func _ready() -> void:
	Game.world = self


func _exit_tree() -> void:
	if Game.world == self:
		Game.world = null


# ------------------------------------------------------------------ building
func build(from_save: bool) -> void:
	ready_done = false
	_rng.seed = WORLD_SEED
	loading_progress.emit(0.02, "Shaping the island")
	WG.setup(WORLD_SEED)
	var th := Thread.new()
	th.start(func():
		WG.build_grid()
		WG.build_vertex_data())
	while th.is_alive():
		await get_tree().process_frame
	th.wait_to_finish()
	loading_progress.emit(0.25, "Raising the land")
	terrain = Terrain.new()
	add_child(terrain)
	await get_tree().process_frame
	var cn := DW.GRID_N / DW.CHUNK_CELLS
	var done := 0
	for cz in cn:
		for cx in cn:
			terrain.build_chunk(cx, cz)
			done += 1
			if done % 4 == 0:
				loading_progress.emit(0.25 + 0.2 * done / float(cn * cn), "Raising the land")
				await get_tree().process_frame
	terrain.build_water()
	sky = SkyEnv.new()
	add_child(sky)
	sky.setup()
	sky.set_quality(Game.quality())
	sky.time_of_day = Game.time_of_day
	decor = Decor.new()
	decor.vis_scale = [0.6, 0.85, 1.15][clampi(Game.quality(), 0, 2)]
	add_child(decor)
	loading_progress.emit(0.5, "Planting forests")
	await get_tree().process_frame
	_populate()
	loading_progress.emit(0.7, "Planting forests")
	await get_tree().process_frame
	decor.flush()
	loading_progress.emit(0.8, "Building ruins")
	await get_tree().process_frame
	_build_sites()
	loading_progress.emit(0.9, "Waking the island")
	await get_tree().process_frame
	build_mgr_setup()
	spawner = Spawner.new()
	spawner.world = self
	add_child(spawner)
	spawner.generate()
	_make_player()
	_make_overlays()
	ready_done = true
	loading_progress.emit(1.0, "Ready")
	loaded.emit()


func _build_sites() -> void:
	sites = preload("res://scripts/world/sites.gd").new()
	sites.build(self)
	preload("res://scripts/world/death_cache.gd").spawn_existing(self)


func pylon_next() -> int:
	if sites == null:
		return 0
	for i in 3:
		if not Game.flag("pylon_%d" % i):
			return i
	return 3


func pylon_reset() -> void:
	for i in 3:
		Game.set_flag("pylon_%d" % i, false)
	Game.stats["interact:pylon"] = 0
	if sites:
		for py in sites.pylons:
			py.active = false


func build_mgr_setup() -> void:
	builder = BuildManager.new()
	builder.world = self
	add_child(builder)


func begin_build(sid: String) -> void:
	builder.begin(sid)


func station_near(station: String) -> bool:
	if player == null:
		return false
	var want: Array = [station]
	if station == "campfire":
		want = ["campfire", "cooking"]
	for s in builder.structures:
		if is_instance_valid(s) and s.sid in want and s.global_position.distance_to(player.global_position) < 7.0:
			return true
	return false


func update_shelter_flag() -> void:
	if player and builder.is_sheltered(player.global_position):
		Game.set_flag("shelter", true)


func open_storage(_s: Node) -> void:
	if hud:
		hud.storage_requested.emit(_s)


func sleep_at(_bed: Node) -> void:
	if sleeping:
		return
	var night: float = sky.night_amount
	if night < 0.4:
		Game.toast("You rest a while. (Sleep is only possible at night.)", "info")
		return
	sleeping = true
	var cl := CanvasLayer.new()
	cl.layer = 20
	add_child(cl)
	var r := ColorRect.new()
	r.color = Color(0, 0, 0, 0)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(r)
	var tw := create_tween()
	tw.tween_property(r, "color:a", 1.0, 0.8)
	tw.tween_callback(func():
		Game.time_of_day = 0.27
		Game.day_count += 1
		Game.health = minf(Game.health + 40.0, Game.max_health)
		Game.hunger = maxf(Game.hunger - 12.0, 10.0)
		Game.stamina = 100.0
		Game.add_stat("sleep")
		save_now(true))
	tw.tween_property(r, "color:a", 0.0, 1.2)
	tw.tween_callback(func():
		cl.queue_free()
		sleeping = false
		Game.toast("You wake at dawn, rested.", "info"))


func _make_player() -> void:
	player = PlayerScript.new()
	player.name = "Player"
	player.world = self
	add_child(player)
	player.touch = touch
	var sp := Vector2(DW.START_POS.x, DW.START_POS.y)
	player.place_at(Vector3(sp.x, WG.height_at(sp.x, sp.y) + 1.0, sp.y))
	player.cam_yaw = PI
	_last_player_pos = player.global_position


func _make_overlays() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 5
	add_child(cl)
	flash = ColorRect.new()
	flash.color = Color(0.8, 0.05, 0.05, 0.0)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(flash)


func hit_flash() -> void:
	if flash == null:
		return
	flash.color.a = 0.28
	var tw := create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.35)


# ------------------------------------------------------------------ scattering
func _noise(x: float, z: float, f: float, seed_off: float) -> float:
	return sin(x * f + seed_off) * cos(z * f * 1.3 - seed_off * 0.7) * 0.5 + 0.5


func _populate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var half := DW.WORLD_SIZE * 0.5
	var step := 4.0
	var site_pos: Array = []
	for k in DW.SITES:
		var s: Dictionary = DW.SITES[k]
		site_pos.append([s["pos"], float(s["flat"]) + 3.0])
	var nid := 0
	var x := -half + 4.0
	while x < half - 4.0:
		var z := -half + 4.0
		while z < half - 4.0:
			var px := x + rng.randf_range(-step, step) * 0.5
			var pz := z + rng.randf_range(-step, step) * 0.5
			z += step
			var h := WG.height_at(px, pz)
			if h < 0.6:
				if h > -1.2 and h < 0.1 and WG.region_at(px, pz) == "coast" and rng.randf() < 0.05:
					_decor_at("reed", px, pz, h, rng, 1.0, 50.0)
				continue
			var slope := WG.slope_at(px, pz)
			var blocked := false
			for sp in site_pos:
				if Vector2(px, pz).distance_to(sp[0]) < sp[1]:
					blocked = true
					break
			var reg := WG.region_at(px, pz)
			# small decor (always, even on site grounds): grass, flowers, ferns
			_scatter_small(reg, px, pz, h, slope, rng)
			if blocked or slope > 0.62:
				continue
			nid = _scatter_resources(reg, px, pz, h, slope, rng, nid)
		x += step


func _decor_at(kind: String, px: float, pz: float, h: float, rng: RandomNumberGenerator, sc: float, range_end: float, variant: int = -1, tint: Color = Color(1, 1, 1)) -> void:
	var v := variant if variant >= 0 else rng.randi() % 3
	var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc)
	decor.add(kind, v, Transform3D(b, Vector3(px, h - 0.05, pz)), tint, range_end)


func _scatter_small(reg: String, px: float, pz: float, h: float, slope: float, rng: RandomNumberGenerator) -> void:
	if slope > 0.8:
		return
	var n := _noise(px, pz, 0.09, 1.7)
	match reg:
		"coast":
			if h > 2.4:
				for i in 3:
					if rng.randf() < 0.55 * n + 0.1:
						_decor_at("grass", px + rng.randf_range(-2, 2), pz + rng.randf_range(-2, 2), h, rng, rng.randf_range(0.8, 1.3), 48.0)
				if rng.randf() < 0.05:
					_decor_at("flower", px, pz, h, rng, 1.0, 40.0, 0)
			elif h < 2.2 and rng.randf() < 0.025:
				_decor_at("shell", px, pz, h, rng, 1.0, 36.0, 0)
		"forest":
			for i in 2:
				if rng.randf() < 0.5:
					_decor_at("grass", px + rng.randf_range(-2, 2), pz + rng.randf_range(-2, 2), h, rng, rng.randf_range(0.9, 1.4), 46.0)
			if rng.randf() < 0.28:
				_decor_at("fern", px, pz, h, rng, rng.randf_range(0.9, 1.5), 55.0)
			if rng.randf() < 0.06:
				_decor_at("flower", px, pz, h, rng, 1.0, 40.0, 0)
		"highlands":
			if rng.randf() < 0.3 and slope < 0.5:
				_decor_at("grass_dry", px, pz, h, rng, rng.randf_range(0.8, 1.2), 40.0)
			if rng.randf() < 0.07:
				_decor_at("rock", px, pz, h, rng, rng.randf_range(0.4, 0.8), 70.0)
		"ashen":
			if rng.randf() < 0.07:
				_decor_at("rock_dark", px, pz, h, rng, rng.randf_range(0.4, 1.0), 80.0)
			if rng.randf() < 0.02:
				_decor_at("rock_ash", px, pz, h, rng, rng.randf_range(0.6, 1.2), 100.0)
		"core":
			if rng.randf() < 0.05:
				_decor_at("rock_dark", px, pz, h, rng, rng.randf_range(0.4, 0.9), 70.0)


# [id, probability per cell]
const RULES := {
	"coast": [["palm", 0.07, 2.6], ["pebbles", 0.03, 0.0], ["branches", 0.02, 2.6], ["fiber_plant", 0.03, 2.6], ["berry_bush", 0.012, 3.0], ["herb_plant", 0.006, 3.0], ["rock", 0.008, 0.0]],
	"forest": [["broadleaf", 0.20, 0.0], ["pine", 0.05, 0.0], ["berry_bush", 0.025, 0.0], ["herb_plant", 0.015, 0.0], ["fiber_plant", 0.04, 0.0], ["mushrooms", 0.012, 0.0], ["branches", 0.035, 0.0], ["rock", 0.008, 0.0], ["pebbles", 0.012, 0.0], ["copper", 0.002, 0.0]],
	"highlands": [["pine", 0.035, 0.0], ["dead_tree", 0.02, 0.0], ["rock", 0.03, 0.0], ["iron", 0.014, 0.0], ["copper", 0.012, 0.0], ["crystal", 0.006, 0.0], ["pebbles", 0.035, 0.0], ["fiber_plant", 0.01, 0.0], ["herb_plant", 0.004, 0.0]],
	"ashen": [["burnt_tree", 0.035, 0.0], ["ember", 0.01, 0.0], ["rock", 0.015, 0.0], ["scrap", 0.006, 0.0], ["pebbles", 0.02, 0.0], ["iron", 0.006, 0.0]],
	"core": [["crystal", 0.012, 0.0], ["scrap", 0.008, 0.0], ["pebbles", 0.012, 0.0], ["iron", 0.005, 0.0], ["copper", 0.004, 0.0]],
}


func _scatter_resources(reg: String, px: float, pz: float, h: float, slope: float, rng: RandomNumberGenerator, nid: int) -> int:
	if not RULES.has(reg):
		return nid
	var density := 0.6 + _noise(px, pz, 0.05, 3.1) * 0.9       # clumping
	for r in RULES[reg]:
		var rid: String = r[0]
		var defs: Dictionary = Data.resources
		var d: Dictionary = defs[rid]
		if d.has("tree") and slope > 0.45:
			continue
		if h < float(r[2]):
			continue
		if rng.randf() < float(r[1]) * density:
			_add_resource(rid, d, px + rng.randf_range(-1.2, 1.2), pz + rng.randf_range(-1.2, 1.2), rng, nid)
			nid += 1
			break
	return nid


func _add_resource(rid: String, d: Dictionary, px: float, pz: float, rng: RandomNumberGenerator, nid: int) -> ResourceNode:
	var h := WG.height_at(px, pz)
	var node := ResourceNode.new()
	node.position = Vector3(px, h, pz)
	add_child(node)
	node.setup(rid, d, nid)
	var sc := float(d["scale"]) * rng.randf_range(0.85, 1.2)
	var v := int(d.get("variant", rng.randi() % maxi(1, 3 if Models_variants(d["model"]) > 1 else 1)))
	var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc)
	var tint := Color(rng.randf_range(0.9, 1.08), rng.randf_range(0.9, 1.08), rng.randf_range(0.9, 1.08))
	var rng_end := 140.0 if d.has("tree") else 90.0
	node.handle = decor.add(d["model"], v, Transform3D(b, Vector3(px, h - 0.05, pz)), tint, rng_end, true)
	resources.append(node)
	return node


func Models_variants(kind: String) -> int:
	return preload("res://scripts/gfx/models.gd").variants(kind)


# ------------------------------------------------------------------ registries / queries
func _cell(p: Vector3) -> Vector2i:
	return Vector2i(int(floor(p.x / HASH_CELL)), int(floor(p.z / HASH_CELL)))


func register_interactable(n: Node3D) -> void:
	var c := _cell(n.global_position)
	if not _hash.has(c):
		_hash[c] = []
	_hash[c].append(n)
	n.set_meta("hc", c)


func unregister_interactable(n: Node) -> void:
	if n.has_meta("hc"):
		var c: Vector2i = n.get_meta("hc")
		if _hash.has(c):
			_hash[c].erase(n)


func interactables_near(p: Vector3, r: float) -> Array:
	var out: Array = []
	var c := _cell(p)
	var k := int(ceil(r / HASH_CELL))
	for dx in range(-k, k + 1):
		for dz in range(-k, k + 1):
			var key := Vector2i(c.x + dx, c.y + dz)
			if _hash.has(key):
				out.append_array(_hash[key])
	return out


func enemies_near(p: Vector3, r: float) -> Array:
	var out: Array = []
	for e in enemies:
		if is_instance_valid(e) and e.alive and e.global_position.distance_to(p) < r:
			out.append(e)
	return out


func hittables_near(p: Vector3, r: float) -> Array:
	var out := enemies_near(p, r)
	for a in animals:
		if is_instance_valid(a) and a.alive and a.global_position.distance_to(p) < r:
			out.append(a)
	return out


func is_cutscene() -> bool:
	return cutscene


func boss_zoom() -> float:
	return 1.0


func is_on_metal(p: Vector3) -> bool:
	for m in metal_zones:
		if Vector2(p.x, p.z).distance_to(m[0]) < m[1]:
			return true
	return false


func temperature_offset(p: Vector3) -> float:
	var reg := WG.region_at(p.x, p.z)
	var off := float(DW.REGIONS[reg]["temp"]) * 42.0
	var night: float = sky.night_amount if sky else 0.0
	if reg != "ashen":
		off -= night * 14.0
	if reg == "highlands":
		off -= clampf((WG.height_at(p.x, p.z) - 30.0) * 0.2, 0.0, 12.0)
	for w in warm_sources:
		var d := p.distance_to(w[0])
		if d < w[1]:
			off += float(w[2]) * (1.0 - d / float(w[1]))
	return off


func spawn_projectile(origin: Vector3, dir: Vector3, dmg: float, from_player: bool, speed: float, col: Color, owner_node: Node) -> void:
	var pr := Projectile.new()
	add_child(pr)
	pr.setup(origin, dir, dmg, from_player, speed, col, owner_node)
	projectiles.append(pr)


## Floating damage number.
func show_damage(pos: Vector3, amount: float, crit: bool) -> void:
	if _dmg_labels.size() < 10:
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.pixel_size = 0.01
		l.font_size = 48
		l.outline_size = 12
		add_child(l)
		_dmg_labels.append(l)
	var lab: Label3D = _dmg_labels[_dmg_i % _dmg_labels.size()]
	_dmg_i += 1
	lab.text = str(int(round(amount)))
	lab.modulate = Color(1.0, 0.85, 0.3) if crit else Color(1, 1, 1)
	lab.scale = Vector3.ONE * (1.4 if crit else 1.0)
	lab.global_position = pos
	lab.visible = true
	var tw := create_tween()
	tw.tween_property(lab, "global_position:y", pos.y + 1.2, 0.7)
	tw.tween_callback(func(): lab.visible = false)


func drop_pickup(id: String, n: int) -> void:
	var pu := Pickup.new()
	pu.position = (player.global_position if player else Vector3.ZERO) + Vector3(randf_range(-1, 1), 0.2, randf_range(-1, 1))
	add_child(pu)
	pu.setup(id, n)


## Small pooled burst of particles.
func spawn_burst(pos: Vector3, col: Color, count: int, speed: float) -> void:
	if _burst_pool.is_empty():
		for i in 14:
			var p := CPUParticles3D.new()
			p.one_shot = true
			p.emitting = false
			p.explosiveness = 1.0
			p.lifetime = 0.7
			p.direction = Vector3.UP
			p.spread = 70.0
			p.gravity = Vector3(0, -9.0, 0)
			p.scale_amount_min = 0.5
			p.scale_amount_max = 1.0
			var sm := SphereMesh.new()
			sm.radius = 0.05
			sm.height = 0.1
			sm.radial_segments = 6
			sm.rings = 3
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.vertex_color_use_as_albedo = true
			sm.material = mat
			p.mesh = sm
			add_child(p)
			_burst_pool.append(p)
	var p: CPUParticles3D = _burst_pool[_burst_i % _burst_pool.size()]
	_burst_i += 1
	p.global_position = pos
	p.amount = maxi(count, 1)
	p.color = col
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.restart()
	p.emitting = true


func on_quest_completed(_id: String) -> void:
	pass


# ------------------------------------------------------------------ saving
func serialize_world() -> Dictionary:
	var dep: Array = []
	for r in resources:
		if r.depleted:
			dep.append([r.node_id, maxf(r.respawn_at - Game.play_seconds, 1.0)])
	var pp := player.global_position
	return {"player": [pp.x, pp.y, pp.z, player.facing_yaw], "depleted": dep, "structures": builder.serialize(), "dens": spawner.serialize()}


func apply_world(d: Dictionary) -> void:
	var byid := {}
	for r in resources:
		byid[r.node_id] = r
	for e in d.get("depleted", []):
		var id := int(e[0])
		if byid.has(id):
			var r: ResourceNode = byid[id]
			r.deplete(false)
			r.respawn_at = Game.play_seconds + float(e[1])
	builder.restore(d.get("structures", []))
	spawner.restore(d.get("dens", []))
	var pl: Array = d.get("player", [])
	if pl.size() >= 4:
		var x := float(pl[0])
		var z := float(pl[2])
		var y := maxf(float(pl[1]), WG.height_at(x, z) + 0.3)
		player.place_at(Vector3(x, y, z))
		player.facing_yaw = float(pl[3])
		player.cam_yaw = float(pl[3]) + PI


func save_now(auto: bool) -> bool:
	if player == null or player.dead:
		return false
	var payload := {"game": Game.serialize(), "inventory": Inv.serialize(), "quests": Quests.serialize(), "world": serialize_world()}
	var ok: bool = Save.write_game(payload)
	if ok:
		if not auto:
			Game.toast("Game saved.", "info")
		else:
			Game.toast("Autosaved.", "info")
	else:
		Game.toast("Could not save! Check free storage space.", "warn")
	return ok


func player_moved(p: Vector3) -> void:
	_last_player_pos = p


# ------------------------------------------------------------------ frame update
func _process(delta: float) -> void:
	if not ready_done:
		return
	_site_acc += delta
	if _site_acc > 0.5 and player:
		_site_acc = 0.0
		Game.reveal_area(player.global_position.x, player.global_position.z, 36.0)
		var pp := Vector2(player.global_position.x, player.global_position.z)
		for sid in DW.SITES:
			if not Game.sites_found.has(sid) and pp.distance_to(DW.SITES[sid]["pos"]) < float(DW.SITES[sid]["flat"]) + 12.0:
				Game.found_site(sid)
				if hud:
					hud.banner(String(DW.SITES[sid]["name"]).to_upper(), "Discovered")
	if Game.is_playing() or Game.state == Game.State.BUILDING:
		var rate: float = 1.0 / float(sky.day_length)
		Game.time_of_day += delta * rate
		if Game.time_of_day >= 1.0:
			Game.time_of_day -= 1.0
			Game.day_count += 1
		sky.time_of_day = Game.time_of_day
	var reg := player_region
	var fog := 0.0016
	var fcol := Color(0.72, 0.82, 0.9)
	var tint := Color(1, 1, 1)
	match reg:
		"forest":
			fog = 0.0032
			fcol = Color(0.6, 0.76, 0.66)
		"highlands":
			fog = 0.0022
			fcol = Color(0.72, 0.78, 0.86)
		"ashen":
			fog = 0.0038
			fcol = Color(0.55, 0.38, 0.30)
			tint = Color(1.05, 0.92, 0.85)
		"core":
			fog = 0.0030
			fcol = Color(0.45, 0.55, 0.72)
	sky.update(delta, fog, fcol, tint, 0.0)
	_shelter_acc += delta
	if _shelter_acc > 1.0:
		_shelter_acc = 0.0
		update_shelter_flag()
	_tick_acc += delta
	if _tick_acc > 0.5:
		_tick_acc = 0.0
		for r in resources:
			if r.depleted:
				r.tick(0.5)
		_update_collisions()
	# resource shake feedback handled in tick; nothing per frame


func _update_collisions() -> void:
	if player == null:
		return
	var pp := player.global_position
	var near: Array = interactables_near(pp, 40.0)
	var keep := {}
	for n in near:
		if n is ResourceNode and is_instance_valid(n):
			if n.global_position.distance_to(pp) < 34.0:
				keep[n] = true
				if not _active_col.has(n):
					n.set_collision(true)
					_active_col[n] = true
	for n in _active_col.keys():
		if not is_instance_valid(n):
			_active_col.erase(n)
		elif not keep.has(n) and n.global_position.distance_to(pp) > 42.0:
			n.set_collision(false)
			_active_col.erase(n)
