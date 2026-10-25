shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
// Stylised vertex-colour shader: COLOR.rgb = albedo, COLOR.a = wind sway weight.
uniform float sway_strength = 0.0;
uniform float rim_strength = 0.25;
uniform float emission_boost = 0.0;
uniform vec3 rim_color : source_color = vec3(0.75, 0.85, 1.0);
uniform float world_noise = 0.12;

varying vec3 v_col;
varying vec3 v_wpos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1, 0)), f.x), mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	v_col = COLOR.rgb;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (sway_strength > 0.0 && COLOR.a > 0.0) {
		float t = TIME * 1.3;
		float ph = wp.x * 0.35 + wp.z * 0.27;
		vec3 off = vec3(sin(t + ph) + 0.4 * sin(t * 2.3 + ph * 1.7), 0.0, cos(t * 0.9 + ph) * 0.7) * sway_strength * COLOR.a;
		VERTEX += (inverse(mat3(MODEL_MATRIX)) * off);
	}
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = vnoise(v_wpos.xz * 1.7 + v_wpos.y * 0.9);
	vec3 c = v_col * (1.0 - world_noise + n * world_noise * 2.0);
	ALBEDO = c;
	ROUGHNESS = 0.88;
	SPECULAR = 0.15;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = rim_color * fres * rim_strength * 0.35 + c * emission_boost;
	if (!FRONT_FACING) { NORMAL = -NORMAL; }
}
