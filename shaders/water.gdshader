shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, diffuse_burley, specular_schlick_ggx;
// Water: depth tint + shore foam baked into vertex colour (R = shallow 0..1, G = foam band, B unused).
uniform vec3 deep_color : source_color = vec3(0.02, 0.18, 0.30);
uniform vec3 shallow_color : source_color = vec3(0.14, 0.62, 0.62);
uniform float wave_speed = 0.6;
varying vec3 v_wpos;
varying vec2 v_info;

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
	v_info = COLOR.rg;
	VERTEX.y += sin(v_wpos.x * 0.35 + TIME * wave_speed) * 0.05 + cos(v_wpos.z * 0.3 + TIME * wave_speed * 0.8) * 0.05;
}

void fragment() {
	vec2 uv1 = v_wpos.xz * 0.35 + vec2(TIME * 0.04, TIME * 0.02);
	vec2 uv2 = v_wpos.xz * 0.9 - vec2(TIME * 0.05, -TIME * 0.03);
	float e = 0.06;
	float h0 = vnoise(uv1) + vnoise(uv2) * 0.5;
	float hx = vnoise(uv1 + vec2(e, 0)) + vnoise(uv2 + vec2(e, 0)) * 0.5;
	float hz = vnoise(uv1 + vec2(0, e)) + vnoise(uv2 + vec2(0, e)) * 0.5;
	vec3 nrm = normalize(vec3((h0 - hx) * 2.2, 1.0, (h0 - hz) * 2.2));
	NORMAL = normalize((VIEW_MATRIX * vec4(nrm, 0.0)).xyz);
	vec3 col = mix(deep_color, shallow_color, v_info.x);
	float foam_wave = 0.5 + 0.5 * sin(v_wpos.x * 0.7 + v_wpos.z * 0.5 - TIME * 1.6 + h0 * 6.0);
	float foam = v_info.y * smoothstep(0.35, 0.9, foam_wave * 0.6 + h0 * 0.5);
	col = mix(col, vec3(0.95, 0.98, 1.0), clamp(foam, 0.0, 1.0));
	ALBEDO = col;
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.7;
	ALPHA = mix(0.88, 0.62, v_info.x) ;
	ALPHA = clamp(ALPHA + foam * 0.4, 0.0, 1.0);
}
