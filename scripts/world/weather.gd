extends Node3D
## Weather: clear, overcast, rain (storm with thunder) and ash fall in the Ashen Expanse.
## Particles follow the player. Rain chills the player unless sheltered. State is not saved (it re-rolls on load).

const WG = preload("res://scripts/world/world_gen.gd")

var world: Node3D
var kind: String = "clear"         # clear, overcast, rain
var intensity: float = 0.0
var _timer: float = 120.0
var _thunder_t: float = 12.0
var rain: GPUParticles3D
var ash: GPUParticles3D
var target_overcast: float = 0.0


func setup(w: Node3D) -> void:
	world = w
	rain = _make_particles(Color(0.7, 0.8, 1.0, 0.55), Vector3(0.025, 0.7, 0.025), Vector3(0, -24, 0), 900, 0.9, 30.0)
	ash = _make_particles(Color(0.75, 0.72, 0.7, 0.8), Vector3(0.06, 0.06, 0.06), Vector3(0.6, -1.6, 0.3), 500, 6.0, 30.0)
	add_child(rain)
	add_child(ash)
	rain.emitting = false
	ash.emitting = false


func _make_particles(col: Color, size: Vector3, vel: Vector3, amount: int, life: float, extent: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.visibility_aabb = AABB(Vector3(-extent, -20, -extent), Vector3(extent * 2, 40, extent * 2))
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(extent, 0.5, extent)
	pm.direction = vel.normalized()
	pm.spread = 4.0
	pm.initial_velocity_min = vel.length() * 0.9
	pm.initial_velocity_max = vel.length() * 1.1
	pm.gravity = Vector3.ZERO
	p.process_material = pm
	var bm := BoxMesh.new()
	bm.size = size
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.material = m
	p.draw_pass_1 = bm
	return p


func is_raining() -> bool:
	return kind == "rain" and intensity > 0.3


## Extra cold applied to the player's temperature by wet weather (negative).
func chill_at(p: Vector3) -> float:
	if not is_raining():
		return 0.0
	if world.builder and world.builder.is_sheltered(p):
		return 0.0
	return -9.0 * intensity


func tick(delta: float, player: Node3D, region: String) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_roll()
	var want := 0.0 if kind == "clear" else (0.5 if kind == "overcast" else 1.0)
	intensity = move_toward(intensity, want, delta * 0.08)
	if region in ["ashen", "core"]:
		want = 0.0
	var show_rain := kind == "rain" and region not in ["ashen", "core"]
	rain.emitting = show_rain and intensity > 0.15
	ash.emitting = region == "ashen"
	if player:
		var pos := player.global_position + Vector3(0, 14, 0)
		rain.global_position = pos
		ash.global_position = player.global_position + Vector3(0, 10, 0)
	target_overcast = intensity * (0.6 if kind == "overcast" else 0.95)
	if region == "ashen":
		target_overcast = maxf(target_overcast, 0.5)
	if show_rain and intensity > 0.8:
		_thunder_t -= delta
		if _thunder_t <= 0.0:
			_thunder_t = randf_range(14.0, 34.0)
			Sfx.play("thunder")


func _roll() -> void:
	_timer = randf_range(150.0, 360.0)
	var r := randf()
	kind = "clear" if r < 0.55 else ("overcast" if r < 0.75 else "rain")
