extends Node3D
## Simple energy bolt. Hostile bolts hurt the player; friendly bolts hurt enemies.

var vel: Vector3 = Vector3.ZERO
var dmg: float = 10.0
var from_player: bool = false
var life: float = 4.0
var radius: float = 0.35
var source: Node = null
var splash: float = 0.0
var homing: float = 0.0
var mesh: MeshInstance3D


func setup(origin: Vector3, dir: Vector3, p_dmg: float, friendly: bool, speed: float, col: Color, src: Node) -> void:
	position = origin
	vel = dir.normalized() * speed
	dmg = p_dmg
	from_player = friendly
	source = src
	mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.2
	sm.height = 0.4
	sm.radial_segments = 8
	sm.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	sm.material = mat
	mesh.mesh = sm
	add_child(mesh)
	var halo := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.38
	hm.height = 0.76
	hm.radial_segments = 8
	hm.rings = 4
	var hmat := StandardMaterial3D.new()
	hmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hmat.albedo_color = Color(col.r, col.g, col.b, 0.3)
	hm.material = hmat
	halo.mesh = hm
	add_child(halo)


func _physics_process(delta: float) -> void:
	if not Game.is_playing():
		return
	life -= delta
	if life <= 0.0:
		_burst()
		return
	if homing > 0.0 and Game.world and Game.world.player and not from_player:
		var to: Vector3 = (Game.world.player.global_position + Vector3(0, 1.1, 0) - global_position).normalized()
		vel = vel.lerp(to * vel.length(), clampf(homing * delta, 0.0, 1.0))
	var step := vel * delta
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + step, 1 | 2)
	var r := space.intersect_ray(q)
	if not r.is_empty():
		global_position = r["position"]
		_burst()
		return
	global_position += step
	var w: Node = Game.world
	if w == null:
		return
	if from_player:
		for e in w.enemies_near(global_position, 8.0):
			if not is_instance_valid(e) or not e.alive:
				continue
			if e.hit_center().distance_to(global_position) < radius + float(e.hit_radius):
				e.take_damage(dmg, global_position - vel.normalized() * 2.0, 5.0, w.player, false)
				Sfx.play_at("hit", global_position, 1.1, 40.0)
				_burst()
				return
	else:
		var p: Node3D = w.player
		if p and not p.dead and (p.global_position + Vector3(0, 1.0, 0)).distance_to(global_position) < radius + 0.6:
			p.hurt(dmg, global_position - vel.normalized() * 2.0, 5.0)
			_burst()


func _burst() -> void:
	if Game.world:
		Game.world.spawn_burst(global_position, Color(0.6, 0.95, 1.0) if from_player else Color(0.8, 0.5, 1.0), 8, 3.0)
		Game.world.projectiles.erase(self)
	queue_free()
