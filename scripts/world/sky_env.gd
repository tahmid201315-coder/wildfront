extends Node3D
## Sun/moon, procedural sky, fog, ambient light and colour grading driven by time of day,
## the player's region and the current weather.

const SKY_SHADER := preload("res://shaders/sky.gdshader")

var env: Environment
var sun: DirectionalLight3D
var sky_mat: ShaderMaterial
var world_env: WorldEnvironment
var time_of_day: float = 0.32        # 0..1, 0.25 = sunrise, 0.5 = noon, 0.75 = sunset
var day_length: float = 720.0        # real seconds per in-game day
var overcast: float = 0.0            # 0..1 weather
var region_fog_density: float = 0.0016
var region_fog_color: Color = Color(0.7, 0.8, 0.9)
var region_tint: Color = Color(1, 1, 1)
var shadows_on: bool = true
var night_amount: float = 0.0
var _fog_density_now: float = 0.0016


func setup() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.7)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.82, 0.92)
	env.fog_density = 0.0016
	env.fog_aerial_perspective = 0.12
	env.fog_sky_affect = 0.55
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_strength = 0.9
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.06
	world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 110.0
	sun.directional_shadow_split_1 = 0.22
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.2
	sun.light_angular_distance = 0.5
	add_child(sun)
	apply_time(0.0)


func set_quality(q: int) -> void:
	shadows_on = q > 0
	sun.shadow_enabled = shadows_on
	sun.directional_shadow_max_distance = 70.0 if q == 1 else 120.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if q == 1 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	env.glow_enabled = q > 0


func hour() -> float:
	return fmod(time_of_day * 24.0, 24.0)


func apply_time(delta: float) -> void:
	time_of_day = fposmod(time_of_day + delta / day_length, 1.0)
	var ang := (time_of_day - 0.25) * TAU          # 0.25 -> sun on horizon rising
	var sun_dir := Vector3(cos(ang) * 0.85, sin(ang), 0.35).normalized()
	sun.look_at_from_position(Vector3.ZERO, -sun_dir, Vector3.UP)
	var elev := sun_dir.y
	var day := smoothstep(-0.12, 0.28, elev)
	night_amount = 1.0 - smoothstep(-0.25, 0.05, elev)
	var golden := (1.0 - smoothstep(0.05, 0.45, absf(elev))) * 0.9 * (1.0 if elev > -0.15 else 0.0)
	var sun_col := Color(1.0, 0.96, 0.88).lerp(Color(1.0, 0.62, 0.34), golden)
	sun.light_color = sun_col
	sun.light_energy = lerpf(0.0, 1.0, day) * lerpf(1.0, 0.45, overcast)
	if elev < -0.1:
		# moon light from the opposite side
		sun.light_energy = 0.18 * night_amount * lerpf(1.0, 0.5, overcast)
		sun.light_color = Color(0.55, 0.65, 1.0)
		sun.look_at_from_position(Vector3.ZERO, sun_dir, Vector3.UP)
	var horizon_day := Color(0.74, 0.84, 0.92)
	var zenith_day := Color(0.22, 0.46, 0.84)
	var horizon_dusk := Color(1.0, 0.58, 0.34)
	var zenith_dusk := Color(0.32, 0.30, 0.55)
	var horizon_night := Color(0.05, 0.07, 0.13)
	var zenith_night := Color(0.01, 0.02, 0.06)
	var hor := horizon_night.lerp(horizon_day, day).lerp(horizon_dusk, golden * (1.0 - overcast * 0.6))
	var zen := zenith_night.lerp(zenith_day, day).lerp(zenith_dusk, golden * 0.8)
	var grey := Color(0.55, 0.58, 0.62) * lerpf(0.25, 1.0, day)
	hor = hor.lerp(grey, overcast * 0.7)
	zen = zen.lerp(grey * 0.8, overcast * 0.8)
	sky_mat.set_shader_parameter("horizon_color", hor)
	sky_mat.set_shader_parameter("zenith_color", zen)
	sky_mat.set_shader_parameter("ground_color", hor * 0.5)
	sky_mat.set_shader_parameter("night", night_amount)
	sky_mat.set_shader_parameter("overcast", overcast)
	sky_mat.set_shader_parameter("cloud_cover", lerpf(0.35, 0.6, overcast))
	sky_mat.set_shader_parameter("sun_dir", sun_dir)
	sky_mat.set_shader_parameter("cloud_color", Color(1, 0.97, 0.94).lerp(Color(1.0, 0.7, 0.55), golden))
	var amb_day := Color(0.55, 0.62, 0.72)
	var amb_night := Color(0.12, 0.16, 0.30)
	var amb := amb_night.lerp(amb_day, day)
	amb = amb.lerp(Color(1.0, 0.7, 0.55), golden * 0.35)
	env.ambient_light_color = amb * region_tint
	env.ambient_light_energy = lerpf(0.62, 0.5, overcast)
	var fog_c := hor.lerp(region_fog_color, 0.45)
	env.fog_light_color = fog_c
	env.fog_sun_scatter = 0.12 * day
	env.tonemap_exposure = lerpf(1.15, 1.0, day)


func update(delta: float, target_fog: float, target_color: Color, target_tint: Color, target_overcast: float) -> void:
	region_fog_color = region_fog_color.lerp(target_color, minf(delta * 0.8, 1.0))
	region_tint = region_tint.lerp(target_tint, minf(delta * 0.8, 1.0))
	overcast = lerpf(overcast, target_overcast, minf(delta * 0.2, 1.0))
	_fog_density_now = lerpf(_fog_density_now, target_fog * (1.0 + overcast * 1.4), minf(delta * 0.6, 1.0))
	env.fog_density = _fog_density_now * lerpf(1.0, 0.6, 1.0 - night_amount) if false else _fog_density_now
	apply_time(delta)
