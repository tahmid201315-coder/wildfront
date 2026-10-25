shader_type spatial;
render_mode diffuse_burley, specular_disabled;
// Terrain: vertex colour carries the biome palette; fragment adds large/small noise variation,
// strata on steep faces, and lava / energy glow from the colour alpha channel.
uniform float detail_scale = 0.9;
uniform float glow_strength = 2.2;
uniform vec3 glow_color : source_color = vec3(1.0, 0.38, 0.06);
varying vec3 v_wpos;
varying vec4 v_col;

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
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_col = COLOR;
}

void fragment() {
	vec3 base = v_col.rgb;
	float n_big = vnoise(v_wpos.xz * 0.11 * detail_scale);
	float n_mid = vnoise(v_wpos.xz * 0.55 * detail_scale);
	float n_small = vnoise(v_wpos.xz * 2.4 * detail_scale);
	float shade = 0.82 + n_big * 0.22 + (n_mid - 0.5) * 0.18 + (n_small - 0.5) * 0.10;
	vec3 c = base * shade;
	// strata on steep faces
	vec3 wn = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float steep = 1.0 - clamp(wn.y, 0.0, 1.0);
	float strata = sin(v_wpos.y * 2.2 + n_mid * 4.0) * 0.5 + 0.5;
	c *= 1.0 - steep * 0.35 * strata;
	ALBEDO = c;
	ROUGHNESS = 0.95;
	float g = smoothstep(0.05, 0.6, v_col.a);
	EMISSION = glow_color * g * glow_strength * (0.75 + 0.25 * sin(TIME * 1.7 + v_wpos.x * 0.3 + v_wpos.z * 0.2));
}
