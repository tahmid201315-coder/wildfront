class_name Stage
extends Node2D
## Hosts one room at a time: level, Kael, entities, effects, camera, hit resolution and room transitions.
## Everything is advanced by tick(dt) so hit-stop works and tests can drive the simulation deterministically.

signal room_loaded(id: String)
signal player_died
signal boss_defeated(id: String)
signal request_dialogue(id: String)
signal request_cutscene(id: String)

const ZOOM := 1.15

var level: Level
var player: Player
var fx: Fx
var camera: Camera2D
var backdrop: Backdrop
var back_layer: CanvasLayer
var entities: Node2D
var hittables: Array = []          # anything with take_hit / hit_rect / alive / uid
var enemies: Array = []
var projectiles: Array = []
var pickups: Array = []
var platforms: Array = []
var interactables: Array = []
var hazards_extra: Array = []      # dynamic damaging rects (boss shockwaves, saw blades): objects with hurt_rect()
var boss: Node = null
var data: LevelData
var room_id: String = ""
var hitstop_t: float = 0.0
var shake_amp: float = 0.0
var shake_t: float = 0.0
var time: float = 0.0
var cam_pos: Vector2 = Vector2.ZERO
var cam_lock: Variant = null        # Rect2 when the camera is pinned to an arena
var flash_color: Color = Color(0, 0, 0, 0)
var flash_a: float = 0.0
var frozen_for_script: bool = false
var rng := RandomNumberGenerator.new()
var respawn_point: Vector2 = Vector2.ZERO
var hud: Node = null
var kills: int = 0
var _entry_name: String = "start"
var headless_instant: bool = false
var pushblocks: Array = []
var puzzles: Dictionary = {}
var puzzle_state: Dictionary = {}
var pending_room: String = ""
var pending_entry: String = "start"
var _lens_check: float = 0.0


func _ready() -> void:
	rng.randomize()
	back_layer = CanvasLayer.new()
	back_layer.layer = -10
	add_child(back_layer)
	backdrop = Backdrop.new()
	back_layer.add_child(backdrop)
	camera = Camera2D.new()
	camera.zoom = Vector2(ZOOM, ZOOM)
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	add_child(camera)
	entities = Node2D.new()
	entities.z_index = 3
	add_child(entities)
	fx = Fx.new()
	add_child(fx)
	player = Player.new()
	player.stage = self
	add_child(player)
	player.died.connect(_on_player_died)


# ------------------------------------------------------------------ rooms
func clear_room() -> void:
	for arr in [enemies, projectiles, pickups, platforms, interactables, hazards_extra]:
		for e in arr:
			if is_instance_valid(e):
				e.queue_free()
		arr.clear()
	hittables.clear()
	boss = null
	if level != null:
		level.queue_free()
		level = null
	fx.clear()
	cam_lock = null


func load_room(d: LevelData, entry: String = "start") -> void:
	clear_room()
	data = d
	room_id = d.id
	_entry_name = entry
	level = Level.new()
	level.stage = self
	add_child(level)
	move_child(level, 0)
	level.setup(d)
	player.level = level
	level.z_index = 0
	backdrop.setup(d.region)
	Game.checkpoint["region"] = d.region
	Game.in_boss_fight = false
	Game.boss_changed.emit(false, "", 1.0)
	Spawner.populate(self, d)
	var sp: Vector2 = spawn_for(entry)
	player.reset_for_spawn(sp)
	respawn_point = sp
	cam_pos = _target_cam(0.0, true)
	camera.position = cam_pos
	Sfx.play_music(d.music if d.music != "" else Defs.REGIONS[d.region]["music"])
	room_loaded.emit(d.id)


func spawn_for(entry: String) -> Vector2:
	var spawns: Dictionary = data.meta.get("spawns", {})
	var tp: Array = spawns.get(entry, spawns.get("start", [2, 2]))
	return Vector2(tp[0] * Level.T + Level.T * 0.5, (tp[1] + 1) * Level.T)


func change_room(room: String, entry: String) -> void:
	var d: LevelData = World.get_room(room)
	if d == null:
		push_warning("missing room " + room)
		return
	Game.checkpoint["level"] = room
	load_room(d, entry)
	Game.progress_changed.emit()


# ------------------------------------------------------------------ main tick
func tick(dt: float) -> void:
	time += dt
	if pending_room != "":
		var pr := pending_room
		pending_room = ""
		change_room(pr, pending_entry)
		return
	_lens_check -= dt
	if _lens_check <= 0.0:
		_lens_check = 1.0
		refresh_lens()
	if hitstop_t > 0.0:
		hitstop_t -= dt
		_tick_cosmetic(dt)
		return
	if frozen_for_script:
		_tick_cosmetic(dt)
		return
	for pl in platforms:
		if is_instance_valid(pl):
			pl.tick(dt)
	player.tick(dt)
	for s in interactables:
		if is_instance_valid(s):
			s.tick(dt)
	for e in enemies:
		if is_instance_valid(e) and e.alive:
			e.tick(dt)
	if boss != null and is_instance_valid(boss) and boss.alive:
		boss.tick(dt)
	for p in projectiles:
		if is_instance_valid(p) and p.alive:
			p.tick(dt)
	for k in pickups:
		if is_instance_valid(k) and k.alive:
			k.tick(dt)
	for hx in hazards_extra:
		if is_instance_valid(hx):
			hx.tick(dt)
			if player.alive and hx.hurt_rect().intersects(player.rect()):
				damage_player(hx.damage, hx.position.x, 1.0)
	_sweep()
	_contact_damage()
	_tick_cosmetic(dt)


func _tick_cosmetic(dt: float) -> void:
	fx.tick(dt)
	level.wind_gust = 0.0
	_update_camera(dt)
	flash_a = maxf(flash_a - dt * 3.0, 0.0)
	backdrop.update_view(cam_pos, get_viewport_rect().size, dt)


func _sweep() -> void:
	_prune(enemies); _prune(projectiles); _prune(pickups); _prune(hazards_extra)
	hittables = hittables.filter(func(h): return is_instance_valid(h) and h.alive)
	interactables = interactables.filter(func(h): return is_instance_valid(h))


func _prune(arr: Array) -> void:
	var i := arr.size() - 1
	while i >= 0:
		var e = arr[i]
		if not is_instance_valid(e) or not e.get("alive"):
			if is_instance_valid(e) and not (e.get("dying") != null and float(e.get("dying")) >= 0.0):
				e.queue_free()
			arr.remove_at(i)
		i -= 1


func _contact_damage() -> void:
	if not player.alive:
		return
	var pr := player.rect()
	for e in enemies:
		if is_instance_valid(e) and e.alive and e.contact_damage > 0.0 and e.contact_rect().intersects(pr):
			damage_player(e.contact_damage, e.position.x, 1.0)
	if boss != null and is_instance_valid(boss) and boss.alive and boss.contact_damage > 0.0 and boss.contact_rect().intersects(pr):
		damage_player(boss.contact_damage, boss.position.x, 1.0)


# ------------------------------------------------------------------ API used by Player / entities
func damage_player(amount: float, from_x: float, knock: float = 1.0) -> bool:
	var d := Game.difficulty()
	var amt := amount * float(d["enemy_dmg"])
	return player.hurt(amt, from_x, knock)


func hit_targets(r: Rect2, info: Dictionary, hit_ids: Dictionary) -> int:
	var n := 0
	for h in hittables:
		if not is_instance_valid(h) or not h.alive:
			continue
		var id: int = h.uid
		if hit_ids.has(id):
			continue
		var hr: Rect2 = h.hit_rect()
		if hr.intersects(r):
			hit_ids[id] = true
			var inf := info.duplicate()
			inf["from"] = player.position
			inf["uid"] = id
			if h.take_hit(inf):
				n += 1
				var pos := hr.get_center()
				fx.slash_hit(pos.lerp(player.center(), 0.3), player.facing)
				fx.number(hr.position + Vector2(hr.size.x * 0.5, -6), str(int(round(inf["damage"]))), Color(1, 1, 1), inf["damage"] >= 20.0)
	return n


func hitstop(t: float) -> void:
	hitstop_t = maxf(hitstop_t, t)


func shake(amount: float) -> void:
	if not Game.settings.get("shake", true):
		return
	shake_amp = maxf(shake_amp, amount)


func flash_screen(c: Color) -> void:
	var a := c.a
	if Game.settings.get("flash_reduce", false):
		a *= 0.25
	flash_color = Color(c.r, c.g, c.b, 1.0)
	flash_a = maxf(flash_a, a)


func spawn_bolt(pos: Vector2, dir: Vector2, dmg: float) -> void:
	var b := Projectile.new()
	b.stage = self
	b.position = pos
	b.vel = dir * 560.0
	b.damage = dmg
	b.friendly = true
	b.kind = "bolt"
	b.color = Color(0.5, 0.95, 1.0)
	b.radius = 8.0
	b.life = 1.2
	b.pierce = 1 if Game.equip_stat("pierce") > 0.0 else 0
	entities.add_child(b)
	projectiles.append(b)


func spawn_enemy_shot(pos: Vector2, vel: Vector2, dmg: float, kind: String = "orb", col: Color = Color(1, 0.4, 0.3), radius: float = 7.0, life: float = 4.0, gravity: float = 0.0) -> Projectile:
	var b := Projectile.new()
	b.stage = self
	b.position = pos
	b.vel = vel
	b.damage = dmg
	b.kind = kind
	b.color = col
	b.radius = radius
	b.life = life
	b.gravity = gravity
	entities.add_child(b)
	projectiles.append(b)
	return b


func spawn_pickup(kind: String, pos: Vector2, amount: int = 1) -> void:
	if pickups.size() > 60:
		return
	var p := Pickup.new()
	p.stage = self
	p.level = level
	p.kind = kind
	p.amount = amount
	p.position = pos
	p.vel = Vector2(rng.randf_range(-110, 110), rng.randf_range(-320, -190))
	entities.add_child(p)
	pickups.append(p)


func drop_loot(pos: Vector2, shards: int, heart_chance: float = 0.2, mana_chance: float = 0.2) -> void:
	var n := maxi(int(round(shards * Game.shard_mult())), 1)
	var big := n / 5
	for i in big:
		spawn_pickup("shard", pos, 5)
	for i in n - big * 5:
		spawn_pickup("shard", pos, 1)
	if rng.randf() < heart_chance:
		spawn_pickup("heart", pos)
	if rng.randf() < mana_chance:
		spawn_pickup("mana", pos)


func stasis_pulse(center: Vector2, radius: float, time_s: float) -> void:
	fx.ring(center, Color(0.7, 0.9, 1.0))
	fx.ring(center, Color(0.4, 0.7, 1.0))
	shake(3.0)
	for pl in platforms:
		if is_instance_valid(pl) and pl.position.distance_to(center) < radius + 120.0:
			pl.frozen_t = time_s
	for e in enemies:
		if is_instance_valid(e) and e.alive and e.position.distance_to(center) < radius:
			e.freeze(time_s)
	for s in interactables:
		if is_instance_valid(s) and s.has_method("on_stasis") and s.position.distance_to(center) < radius:
			s.on_stasis(time_s)
	for hz in hazards_extra:
		if is_instance_valid(hz) and hz.position.distance_to(center) < radius + 200.0:
			hz.freeze(time_s)
	if boss != null and is_instance_valid(boss) and boss.alive and boss.has_method("freeze") and boss.position.distance_to(center) < radius:
		boss.freeze(time_s * 0.4)


func try_interact(p: Player) -> bool:
	var best: Node = null
	var best_d := 1e9
	var pr := p.rect().grow(10.0)
	for s in interactables:
		if not is_instance_valid(s) or not s.can_use():
			continue
		var r: Rect2 = s.use_rect()
		if r.intersects(pr):
			var d: float = s.position.distance_to(p.position)
			if d < best_d:
				best_d = d
				best = s
	if best == null:
		return false
	best.use(p)
	return true


func nearest_prompt() -> Dictionary:
	var pr := player.rect().grow(10.0)
	var best: Dictionary = {}
	var best_d := 1e9
	for s in interactables:
		if is_instance_valid(s) and s.can_use() and s.use_rect().intersects(pr):
			var d: float = s.position.distance_to(player.position)
			if d < best_d:
				best_d = d
				best = {"text": s.prompt(), "pos": s.position}
	return best


func add_entity(n: Node2D) -> void:
	entities.add_child(n)


# ------------------------------------------------------------------ puzzles
func puzzle_done(g: String) -> bool:
	return g != "" and puzzle_state.has(g) and puzzle_state[g]["done"]


func switch_pressed(g: String, sw: Interactable) -> void:
	if not puzzle_state.has(g) or puzzle_state[g]["done"]:
		sw.set_active(true)
		return
	var ps: Dictionary = puzzle_state[g]
	var kind: String = str(puzzles[g].get("kind", "all"))
	if kind == "sequence":
		if sw.order == ps["next"]:
			sw.set_active(true)
			ps["next"] += 1
			if ps["next"] > int(puzzles[g].get("count", 3)):
				solve_puzzle(g)
		else:
			Game.toast.emit("The switches fade. Wrong order. Try again.", "info")
			Sfx.play("wrong")
			ps["next"] = 1
			for o in interactables:
				if is_instance_valid(o) and o.kind == "switch" and o.group == g:
					o.set_active(false)
	else:
		sw.set_active(true)
		var n := 0
		for o in interactables:
			if is_instance_valid(o) and o.kind == "switch" and o.group == g and o.active:
				n += 1
		if n >= int(puzzles[g].get("count", 1)):
			solve_puzzle(g)


func plate_changed(g: String, plate: Interactable, pressed: bool) -> void:
	if not puzzle_state.has(g) or puzzle_state[g]["done"]:
		return
	puzzle_state[g]["plates"][plate.uid] = pressed
	var all := true
	var n := 0
	for o in interactables:
		if is_instance_valid(o) and o.kind == "plate" and o.group == g:
			n += 1
			if not puzzle_state[g]["plates"].get(o.uid, false):
				all = false
	if all and n > 0:
		solve_puzzle(g)


func beam_hit_target(g: String, _t: Interactable) -> void:
	if puzzle_state.has(g) and not puzzle_state[g]["done"]:
		solve_puzzle(g)


func solve_puzzle(g: String) -> void:
	if not puzzle_state.has(g) or puzzle_state[g]["done"]:
		return
	puzzle_state[g]["done"] = true
	Game.set_flag("puzzle_%s_%s" % [room_id, g])
	Game.toast.emit("Something ancient grinds open.", "good")
	Sfx.play("puzzle")
	shake(3.0)
	_open_gates(g, false)
	Game.event.emit("puzzle")


func _open_gates(g: String, silent: bool) -> void:
	for c in puzzles.get(g, {}).get("gates", []):
		if level.tile(int(c[0]), int(c[1])) == Tiles.GATE:
			level.set_tile(int(c[0]), int(c[1]), Tiles.AIR)
			if not silent:
				fx.burst(Vector2((int(c[0]) + 0.5) * Level.T, (int(c[1]) + 0.5) * Level.T), Color(1.0, 0.9, 0.5), 5, 140.0)


func refresh_lens() -> void:
	if level != null:
		level.lens_reveal = Game.equip_stat("reveal") > 0.0


# ------------------------------------------------------------------ rooms, dialogue, saving
func request_room_change(room: String, entry: String) -> void:
	pending_room = room
	pending_entry = entry


func spawn_boss(_id: String, _pos: Vector2) -> Node:
	return null


func talk_to(npc_id: String, _src: Node) -> void:
	if hud != null and hud.has_method("open_npc"):
		hud.open_npc(npc_id)
	else:
		Game.toast.emit(Story.npc_line(npc_id, 0), "info")


func show_text(title: String, text: String) -> void:
	if hud != null and hud.has_method("show_text"):
		hud.show_text(title, text)
	else:
		Game.toast.emit(title + ": " + text, "info")


func autosave() -> bool:
	return Save.write_slot(Game.slot, Game.serialize())


# ------------------------------------------------------------------ death & checkpoints
func _on_player_died() -> void:
	player_died.emit()


func respawn_at_checkpoint() -> void:
	var cp: Dictionary = Game.checkpoint
	var rid: String = cp.get("level", room_id)
	var cid: String = str(cp.get("id", "start"))
	Game.full_restore()
	if rid != room_id or data == null:
		change_room(rid, cid)
	else:
		load_room(data, cid)
	player.invuln_t = 1.5


func set_checkpoint(cid: String, pos: Vector2) -> void:
	Game.checkpoint = {"region": data.region, "level": room_id, "id": cid}
	respawn_point = pos


# ------------------------------------------------------------------ camera
func _target_cam(dt: float, snap: bool = false) -> Vector2:
	var vp := get_viewport_rect().size / ZOOM
	var want := player.center() + Vector2(float(player.facing) * 48.0, -34.0)
	if snap:
		want = player.center() + Vector2(0, -34.0)
	var bounds := Rect2(Vector2.ZERO, level.pixel_size())
	if cam_lock is Rect2:
		bounds = cam_lock
	var half := vp * 0.5
	var lo := bounds.position + half
	var hi := bounds.end - half
	if hi.x < lo.x:
		want.x = bounds.get_center().x
	else:
		want.x = clampf(want.x, lo.x, hi.x)
	if hi.y < lo.y:
		want.y = bounds.get_center().y
	else:
		want.y = clampf(want.y, lo.y, hi.y)
	return want


func _update_camera(dt: float) -> void:
	var want := _target_cam(dt)
	var k := 1.0 - exp(-7.0 * dt)
	cam_pos = cam_pos.lerp(want, k)
	shake_amp = maxf(shake_amp - 30.0 * dt - shake_amp * 4.0 * dt, 0.0)
	var off := Vector2.ZERO
	if shake_amp > 0.3:
		off = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * shake_amp
	camera.position = (cam_pos + off).round()


# ------------------------------------------------------------------ queries used by tests / UI
func living_enemies() -> int:
	var n := 0
	for e in enemies:
		if is_instance_valid(e) and e.alive:
			n += 1
	return n


func _physics_process(delta: float) -> void:
	if level == null or headless_instant:
		return
	if Game.state == Game.State.PLAY:
		tick(delta)
	elif Game.state == Game.State.GAMEOVER or Game.state == Game.State.CUTSCENE:
		pass
