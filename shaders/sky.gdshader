shader_type sky;
// Procedural sky: gradient, sun/moon, stars at night and drifting clouds.
uniform vec3 horizon_color : source_color = vec3(0.75, 0.82, 0.9);
uniform vec3 zenith_color : source_color = vec3(0.25, 0.48, 0.85);
uniform vec3 ground_color : source_color = vec3(0.12, 0.16, 0.2);
uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float night = 0.0;
uniform float cloud_cover = 0.45;
uniform float overcast = 0.0;
uniform vec3 sun_dir = vec3(0.3, 0.8, 0.3);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float hash31(vec3 p) {
	p = fract(p * vec3(443.897, 441.423, 437.195));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1, 0)), f.x), mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float a = 0.5; float s = 0.0;
	for (int i = 0; i < 4; i++) { s += a * vnoise(p); p *= 2.07; a *= 0.5; }
	return s;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float up = clamp(d.y, -1.0, 1.0);
	vec3 col = mix(horizon_color, zenith_color, pow(clamp(up, 0.0, 1.0), 0.55));
	if (up < 0.0) { col = mix(horizon_color, ground_color, clamp(-up * 3.0, 0.0, 1.0)); }
	vec3 sd = normalize(sun_dir);
	float sd_dot = max(dot(d, sd), 0.0);
	float sun_height = clamp(sd.y * 1.8 + 0.3, 0.0, 1.0);
	// sun disc + glow
	col += vec3(1.0, 0.82, 0.55) * pow(sd_dot, 900.0) * 6.0 * sun_height;
	col += vec3(1.0, 0.6, 0.3) * pow(sd_dot, 14.0) * 0.45 * sun_height;
	// moon opposite the sun
	vec3 md = -sd;
	float md_dot = max(dot(d, md), 0.0);
	col += vec3(0.8, 0.88, 1.0) * smoothstep(0.9985, 0.9992, md_dot) * night * 1.6;
	col += vec3(0.4, 0.5, 0.8) * pow(md_dot, 40.0) * 0.12 * night;
	// stars
	if (up > 0.0 && night > 0.02) {
		vec3 sp = floor(d * 190.0);
		float h = hash31(sp);
		float star = smoothstep(0.9965, 1.0, h) * (0.5 + 0.5 * sin(TIME * 2.0 + h * 40.0));
		col += vec3(1.0) * star * night * (1.0 - overcast) * clamp(up * 3.0, 0.0, 1.0);
	}
	// clouds on a plane
	if (up > 0.02) {
		vec2 cp = d.xz / (up + 0.18) * 0.9 + vec2(TIME * 0.006, TIME * 0.002);
		float c = fbm(cp * 1.4);
		float cov = clamp(cloud_cover + overcast * 0.5, 0.0, 1.0);
		float m = smoothstep(1.0 - cov * 0.85, 1.0 - cov * 0.85 + 0.25, c);
		m *= smoothstep(0.02, 0.25, up);
		vec3 cc = cloud_color * mix(1.0, 0.55, overcast);
		float lit = clamp(dot(vec3(0.0, 1.0, 0.0), sd) * 0.5 + 0.55, 0.15, 1.0);
		col = mix(col, cc * lit + horizon_color * 0.15, m * (0.65 + overcast * 0.3));
	}
	COLOR = col;
}
