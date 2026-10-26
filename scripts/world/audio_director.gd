extends RefCounted
## Chooses music and ambience layers from region, time of day, combat, bosses and weather.

const WG = preload("res://scripts/world/world_gen.gd")

var _acc: float = 0.0
var _combat_hold: float = 0.0


func tick(world: Node3D, delta: float) -> void:
	_acc += delta
	_combat_hold = maxf(_combat_hold - delta, 0.0)
	if _acc < 0.5 or world.player == null:
		return
	_acc = 0.0
	var p: Node3D = world.player
	var region: String = world.player_region
	var night: float = world.sky.night_amount if world.sky else 0.0
	var boss := false
	var combat := false
	for e in world.enemies:
		if not is_instance_valid(e) or not e.alive:
			continue
		var d: float = e.global_position.distance_to(p.global_position)
		if e.get("bid") != null and e.state not in ["dormant", "dead"]:
			boss = true
		elif d < 22.0 and e.state in ["chase", "windup", "attack"]:
			combat = true
	if combat:
		_combat_hold = 8.0
	var track := "day"
	if boss:
		track = "boss"
	elif _combat_hold > 0.0:
		track = "combat"
	elif region == "ashen":
		track = "ashen"
	elif region == "core":
		track = "core"
	elif night > 0.55:
		track = "night"
	Sfx.play_music(track)
	var h := WG.height_at(p.global_position.x, p.global_position.z)
	var layers := {}
	if h < 6.0 and region == "coast":
		layers["waves"] = 0.8
	if region == "highlands":
		layers["wind"] = 0.7
	elif region == "forest":
		layers["wind"] = 0.25
	else:
		layers["wind"] = 0.15
	if region == "ashen":
		layers["steam"] = 0.5
		layers["rumble"] = 0.45
	if region == "core":
		layers["hum"] = 0.6
		layers["rumble"] = 0.3
	if night > 0.5 and region in ["coast", "forest"]:
		layers["crickets"] = 0.5 * night
	if world.weather and world.weather.is_raining() and region not in ["ashen", "core"]:
		layers["rain"] = 0.8 * world.weather.intensity
	for ws in world.warm_sources:
		if p.global_position.distance_to(ws[0]) < 12.0:
			layers["fire"] = 0.6
			break
	Sfx.set_ambience(layers)
